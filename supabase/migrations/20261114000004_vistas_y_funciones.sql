-- ChangePlanner TI · Semana 3 · Migración 4 de 5: vistas de lectura y funciones del flujo central

create or replace view public.v_cambios_detalle as
select
  c.id,
  s.anio               as semana_anio,
  s.semana             as semana_num,
  c.fecha_ingreso,
  e.codigo_empleado,
  e.usuario,
  a.nombre             as area,
  a.codigo             as id_area,
  sol.codigo_solicitud as id_solicitud,
  r.codigo_rfc         as rfc,
  am.nombre            as rfc_ambito,
  r.id_rfc_bi,
  c.actividad,
  cl.nombre            as clasificacion,
  rc.nombre            as resultado,
  c.confirmacion,
  ap.aprobado_por,
  ap.fecha_aprobacion,
  c.firmadas,
  c.observaciones,
  c.estado
from public.cambios c
join public.semanas s            on s.id  = c.semana_id
join public.empleados e          on e.id  = c.empleado_id
join public.areas a              on a.id  = c.area_id
join public.clasificaciones cl   on cl.id = c.clasificacion_id
join public.resultados_cambio rc on rc.id = c.resultado_id
left join public.solicitudes sol on sol.id = c.solicitud_id
left join public.rfcs r          on r.id  = c.rfc_id
left join public.ambitos_rfc am  on am.id = r.ambito_id
left join lateral (
  select x.aprobado_por, x.fecha_aprobacion
  from public.aprobaciones_semanales x
  where x.semana_id = c.semana_id
  order by x.id desc
  limit 1
) ap on c.estado in ('Aprobado', 'Rechazado');

create or replace view public.v_resumen_semana as
select
  s.id as semana_id,
  s.anio,
  s.semana,
  s.fecha_inicio,
  s.fecha_fin,
  s.estado as estado_semana,
  count(c.id)::int                                                    as total_cambios,
  (count(*) filter (where c.estado = 'Por aprobar'))::int             as total_pendientes,
  (count(*) filter (where c.estado = 'Aprobado'))::int                as total_aprobados,
  (count(*) filter (where c.estado = 'Rechazado'))::int               as total_rechazados,
  (count(*) filter (where c.id is not null and not c.firmadas))::int  as total_sin_firmar,
  (select x.aprobado_por     from public.aprobaciones_semanales x where x.semana_id = s.id order by x.id desc limit 1) as aprobado_por,
  (select x.fecha_aprobacion from public.aprobaciones_semanales x where x.semana_id = s.id order by x.id desc limit 1) as fecha_aprobacion
from public.semanas s
left join public.cambios c on c.semana_id = s.id
group by s.id;

create or replace view public.v_cambios_por_usuario as
select
  s.anio,
  s.semana,
  e.usuario,
  a.nombre as area,
  count(*)::int as cambios
from public.cambios c
join public.semanas s   on s.id = c.semana_id
join public.empleados e on e.id = c.empleado_id
join public.areas a     on a.id = c.area_id
group by s.anio, s.semana, e.id, e.usuario, a.id, a.nombre;

-- Flujo central 1: registrar un cambio (valida y crea empleado/solicitud/RFC si hace falta, en una sola transacción)
create or replace function public.registrar_cambio(
  p_fecha_ingreso    date,
  p_codigo_empleado  text,
  p_usuario          text,
  p_area_id          bigint,
  p_id_solicitud     text,
  p_rfc              text,
  p_ambito_id        bigint,
  p_id_rfc_bi        text,
  p_actividad        text,
  p_clasificacion_id bigint,
  p_resultado_id     bigint,
  p_confirmacion     boolean,
  p_firmadas         boolean,
  p_observaciones    text
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_usuario    text := btrim(coalesce(p_usuario, ''));
  v_codigo     text := nullif(btrim(coalesce(p_codigo_empleado, '')), '');
  v_solicitud  text := nullif(btrim(coalesce(p_id_solicitud, '')), '');
  v_rfc        text := nullif(btrim(coalesce(p_rfc, '')), '');
  v_bi         text := nullif(btrim(coalesce(p_id_rfc_bi, '')), '');
  v_actividad  text := btrim(coalesce(p_actividad, ''));
  v_obs        text := nullif(btrim(coalesce(p_observaciones, '')), '');
  v_requiere   boolean;
  v_emp_id     bigint;
  v_emp_codigo text;
  v_sol_id     bigint;
  v_rfc_id     bigint;
  v_cambio_id  bigint;
begin
  if p_fecha_ingreso is null then raise exception 'La fecha de ingreso es obligatoria.'; end if;
  if v_usuario = '' then raise exception 'El usuario es obligatorio.'; end if;
  if char_length(v_actividad) < 10 then
    raise exception 'La actividad debe describirse con al menos 10 caracteres.';
  end if;
  if not exists (select 1 from areas where id = p_area_id and activa) then
    raise exception 'Selecciona un área válida.';
  end if;

  select requiere_justificacion into v_requiere from clasificaciones where id = p_clasificacion_id;
  if not found then raise exception 'Selecciona una clasificación válida.'; end if;
  if not exists (select 1 from resultados_cambio where id = p_resultado_id) then
    raise exception 'Selecciona un resultado válido.';
  end if;
  if v_requiere and char_length(coalesce(v_obs, '')) < 10 then
    raise exception 'Este tipo de cambio requiere una justificación en Observaciones (mínimo 10 caracteres).';
  end if;
  if v_rfc is not null and not exists (select 1 from ambitos_rfc where id = p_ambito_id) then
    raise exception 'Indica si el RFC es Local o Regional.';
  end if;

  -- Empleado: se busca por usuario; si no existe se crea con rol Ejecutor
  select id, codigo_empleado into v_emp_id, v_emp_codigo from empleados where lower(usuario) = lower(v_usuario);
  if v_emp_id is null then
    if v_codigo is not null and exists (select 1 from empleados where codigo_empleado = v_codigo) then
      raise exception 'El código de empleado % ya pertenece a otro usuario.', v_codigo;
    end if;
    insert into empleados (codigo_empleado, usuario, area_id, rol_id)
    values (v_codigo, v_usuario, p_area_id, (select id from roles where nombre = 'Ejecutor'))
    returning id into v_emp_id;
  elsif v_codigo is not null then
    if v_emp_codigo is null then
      if exists (select 1 from empleados where codigo_empleado = v_codigo) then
        raise exception 'El código de empleado % ya pertenece a otro usuario.', v_codigo;
      end if;
      update empleados set codigo_empleado = v_codigo where id = v_emp_id;
    elsif v_emp_codigo <> v_codigo then
      raise exception 'El código de empleado no coincide con el registrado para el usuario %.', v_usuario;
    end if;
  end if;

  if v_solicitud is not null then
    insert into solicitudes (codigo_solicitud) values (v_solicitud)
    on conflict (codigo_solicitud) do update set codigo_solicitud = excluded.codigo_solicitud
    returning id into v_sol_id;
  end if;

  if v_rfc is not null then
    insert into rfcs (codigo_rfc, ambito_id, id_rfc_bi) values (v_rfc, p_ambito_id, v_bi)
    on conflict (codigo_rfc) do update
      set ambito_id = excluded.ambito_id,
          id_rfc_bi = coalesce(excluded.id_rfc_bi, rfcs.id_rfc_bi)
    returning id into v_rfc_id;
  end if;

  insert into cambios (fecha_ingreso, empleado_id, area_id, solicitud_id, rfc_id, actividad,
                       clasificacion_id, resultado_id, confirmacion, firmadas, observaciones)
  values (p_fecha_ingreso, v_emp_id, p_area_id, v_sol_id, v_rfc_id, v_actividad,
          p_clasificacion_id, p_resultado_id, coalesce(p_confirmacion, false), coalesce(p_firmadas, false), v_obs)
  returning id into v_cambio_id;

  return v_cambio_id;
end $$;

-- Flujo central 2: aprobar o rechazar la semana completa
create or replace function public.aprobar_semana(
  p_anio             int,
  p_semana           int,
  p_decision         text,
  p_aprobado_por     text,
  p_fecha_aprobacion date,
  p_comentarios      text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_sem   semanas%rowtype;
  v_por   text := btrim(coalesce(p_aprobado_por, ''));
  v_com   text := nullif(btrim(coalesce(p_comentarios, '')), '');
  v_total int;
begin
  if p_decision not in ('Aprobada', 'Rechazada') then
    raise exception 'La decisión debe ser Aprobada o Rechazada.';
  end if;
  if char_length(v_por) < 3 then raise exception 'Indica quién aprueba (mínimo 3 caracteres).'; end if;
  if p_fecha_aprobacion is null then raise exception 'La fecha de aprobación es obligatoria.'; end if;
  if p_fecha_aprobacion > current_date then raise exception 'La fecha de aprobación no puede ser futura.'; end if;
  if p_decision = 'Rechazada' and char_length(coalesce(v_com, '')) < 5 then
    raise exception 'Para rechazar una semana debes escribir un comentario (mínimo 5 caracteres).';
  end if;

  select * into v_sem from semanas where anio = p_anio and semana = p_semana for update;
  if not found then
    raise exception 'La semana % de % no tiene cambios registrados.', p_semana, p_anio;
  end if;
  if v_sem.estado = 'Aprobada' then
    raise exception 'La semana % de % ya fue aprobada.', p_semana, p_anio;
  end if;

  select count(*) into v_total from cambios where semana_id = v_sem.id;
  if v_total = 0 then raise exception 'La semana no tiene cambios para aprobar.'; end if;

  insert into aprobaciones_semanales (semana_id, decision, aprobado_por, fecha_aprobacion, comentarios)
  values (v_sem.id, p_decision, v_por, p_fecha_aprobacion, v_com);

  update semanas set estado = p_decision where id = v_sem.id;
  update cambios
     set estado = case p_decision when 'Aprobada' then 'Aprobado' else 'Rechazado' end
   where semana_id = v_sem.id;
end $$;
