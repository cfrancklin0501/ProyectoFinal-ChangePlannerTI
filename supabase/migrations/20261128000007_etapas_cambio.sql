-- ChangePlanner TI · Semana 5 · Migración 7: registro de cambios por etapas
--
-- Hallazgo bloqueante de la prueba con usuarios (docs/pruebas-usuarios.md, H1):
-- el proceso real no captura todo al registrar. Un cambio pasa por tres etapas:
--   1. Registrado          → se ingresa la solicitud (sin resultado ni confirmación).
--   2. Aprobado en sesión  → se revisó en la sesión de control de cambios, se manda a firmar.
--   3. Ejecutado           → ya se ejecutó: se documenta el resultado (Exitoso / Fallido / Revertido)
--                            y la confirmación.
-- El registro crea la etapa 1; las etapas 2 y 3 son actualizaciones de estado (función avanzar_etapa).
--
-- Requisito: haber ejecutado las migraciones 1 a 6.

-- =====================================================================
-- 1. NUEVAS COLUMNAS EN CAMBIOS
-- =====================================================================
alter table public.cambios
  add column etapa           text not null default 'Registrado',
  add column fecha_sesion    date,
  add column fecha_ejecucion date,
  add constraint cambios_etapa_valida
    check (etapa in ('Registrado', 'Aprobado en sesión', 'Ejecutado')),
  add constraint cambios_fecha_sesion_valida
    check (fecha_sesion is null or fecha_sesion >= fecha_ingreso),
  add constraint cambios_fecha_ejecucion_valida
    check (fecha_ejecucion is null or fecha_ejecucion >= coalesce(fecha_sesion, fecha_ingreso)),
  add constraint cambios_sesion_requiere_fecha
    check (etapa = 'Registrado' or fecha_sesion is not null),
  add constraint cambios_ejecucion_requiere_fecha
    check (etapa <> 'Ejecutado' or fecha_ejecucion is not null);

comment on column public.cambios.etapa is
  'Registrado → Aprobado en sesión → Ejecutado. Solo avanza con la función avanzar_etapa.';

create index cambios_etapa_idx on public.cambios (etapa);

-- Cambios que ya existían: se deduce la etapa de lo que tienen capturado.
-- Se desactivan los triggers solo durante esta corrección de datos (semanas aprobadas, historial, permisos).
alter table public.cambios disable trigger user;

update public.cambios c
   set etapa = case
                 when rc.nombre <> 'Pendiente' then 'Ejecutado'
                 when c.firmadas then 'Aprobado en sesión'
                 else 'Registrado'
               end,
       fecha_sesion = case
                        when rc.nombre <> 'Pendiente' or c.firmadas then c.fecha_ingreso
                      end,
       fecha_ejecucion = case when rc.nombre <> 'Pendiente' then c.fecha_ingreso end
  from public.resultados_cambio rc
 where rc.id = c.resultado_id;

alter table public.cambios enable trigger user;

-- =====================================================================
-- 2. REGLAS DE LAS ETAPAS (trigger)
-- =====================================================================
-- * El resultado final (Exitoso / Fallido / Revertido) solo existe en la etapa Ejecutado, y la etapa
--   Ejecutado siempre tiene un resultado final.
-- * Por la API, un cambio nuevo siempre empieza en la etapa 1 con resultado Pendiente, sin confirmación ni firmas.
create or replace function public.trg_cambios_etapa()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_resultado text;
begin
  select nombre into v_resultado from resultados_cambio where id = new.resultado_id;

  if tg_op = 'INSERT' and coalesce(auth.role(), '') in ('anon', 'authenticated') then
    if v_resultado <> 'Pendiente' then
      raise exception 'Al registrar un cambio el resultado queda Pendiente. El resultado se documenta en la etapa 3 (Ejecutado).';
    end if;
    new.etapa           := 'Registrado';
    new.fecha_sesion    := null;
    new.fecha_ejecucion := null;
    new.confirmacion    := false;
    new.firmadas        := false;
    return new;
  end if;

  if tg_op = 'INSERT' and new.etapa = 'Registrado' and v_resultado <> 'Pendiente' then
    -- Carga por SQL (semilla): un cambio con resultado final ya está ejecutado
    new.etapa           := 'Ejecutado';
    new.fecha_sesion    := coalesce(new.fecha_sesion, new.fecha_ingreso);
    new.fecha_ejecucion := coalesce(new.fecha_ejecucion, new.fecha_ingreso);
  end if;

  if new.etapa = 'Ejecutado' and v_resultado = 'Pendiente' then
    raise exception 'Un cambio ejecutado debe tener resultado: Exitoso, Fallido o Revertido.';
  end if;
  if new.etapa <> 'Ejecutado' and v_resultado <> 'Pendiente' then
    raise exception 'El resultado se registra en la etapa 3 (Ejecutado). Este cambio está en la etapa «%».', new.etapa;
  end if;

  return new;
end $$;

create trigger cambios_etapa before insert or update on public.cambios
  for each row execute function public.trg_cambios_etapa();

-- =====================================================================
-- 3. AVANZAR DE ETAPA (Administrador)
-- =====================================================================
-- Etapa 1 → 2: p_fecha = fecha de la sesión; p_firmadas = si ya se mandó a firmar / está firmado.
-- Etapa 2 → 3: p_fecha = fecha de ejecución; p_resultado_id (no Pendiente); p_confirmacion.
-- Devuelve la etapa nueva.
create or replace function public.avanzar_etapa(
  p_id            bigint,
  p_fecha         date,
  p_firmadas      boolean,
  p_resultado_id  bigint,
  p_confirmacion  boolean,
  p_observaciones text
) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_c         cambios%rowtype;
  v_resultado text;
  v_obs       text := nullif(btrim(coalesce(p_observaciones, '')), '');
begin
  perform public.exigir_rol(array['Administrador']);

  select * into v_c from cambios where id = p_id for update;
  if not found then raise exception 'El cambio #% no existe.', p_id; end if;
  if v_c.estado = 'Aprobado' then
    raise exception 'El cambio #% pertenece a una semana aprobada por gerencia y ya no se modifica.', p_id;
  end if;
  if p_fecha is null then raise exception 'Indica la fecha.'; end if;
  if p_fecha > current_date then raise exception 'La fecha no puede ser futura.'; end if;

  if v_c.etapa = 'Registrado' then
    if p_fecha < v_c.fecha_ingreso then
      raise exception 'La fecha de la sesión no puede ser anterior a la fecha de ingreso (%).', v_c.fecha_ingreso;
    end if;
    update cambios
       set etapa         = 'Aprobado en sesión',
           fecha_sesion  = p_fecha,
           firmadas      = coalesce(p_firmadas, firmadas),
           observaciones = coalesce(v_obs, observaciones)
     where id = p_id;
    return 'Aprobado en sesión';

  elsif v_c.etapa = 'Aprobado en sesión' then
    if p_fecha < v_c.fecha_sesion then
      raise exception 'La fecha de ejecución no puede ser anterior a la fecha de la sesión (%).', v_c.fecha_sesion;
    end if;
    select nombre into v_resultado from resultados_cambio where id = p_resultado_id;
    if not found or v_resultado = 'Pendiente' then
      raise exception 'Indica el resultado de la ejecución: Exitoso, Fallido o Revertido.';
    end if;
    if v_resultado in ('Fallido', 'Revertido') and char_length(coalesce(v_obs, v_c.observaciones, '')) < 10 then
      raise exception 'Si el cambio fue % explica qué pasó en Observaciones (mínimo 10 caracteres).', lower(v_resultado);
    end if;
    update cambios
       set etapa           = 'Ejecutado',
           fecha_ejecucion = p_fecha,
           resultado_id    = p_resultado_id,
           confirmacion    = coalesce(p_confirmacion, false),
           firmadas        = coalesce(p_firmadas, firmadas),
           observaciones   = coalesce(v_obs, observaciones)
     where id = p_id;
    return 'Ejecutado';

  else
    raise exception 'El cambio #% ya está en la última etapa (Ejecutado).', p_id;
  end if;
end $$;

-- =====================================================================
-- 4. LA SEMANA SOLO SE APRUEBA CUANDO TODOS SUS CAMBIOS ESTÁN EJECUTADOS
-- =====================================================================
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
  v_sem       semanas%rowtype;
  v_por       text := btrim(coalesce(p_aprobado_por, ''));
  v_com       text := nullif(btrim(coalesce(p_comentarios, '')), '');
  v_total     int;
  v_sin_ejec  int;
  v_perfil    perfiles%rowtype;
begin
  perform public.exigir_rol(array['Aprobador']);

  if auth.uid() is not null then
    select * into v_perfil from perfiles where id = auth.uid();
    if lower(v_por) <> lower(v_perfil.nombre_completo) then
      raise exception 'Solo puedes registrar la decisión con tu propio usuario (%).', v_perfil.nombre_completo;
    end if;
    v_por := v_perfil.nombre_completo;
  end if;

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

  select count(*), count(*) filter (where etapa <> 'Ejecutado')
    into v_total, v_sin_ejec
    from cambios where semana_id = v_sem.id;
  if v_total = 0 then raise exception 'La semana no tiene cambios para aprobar.'; end if;
  if p_decision = 'Aprobada' and v_sin_ejec > 0 then
    raise exception 'No se puede aprobar todavía: % de % cambios de la semana aún no están ejecutados (etapa 1 o 2).',
      v_sin_ejec, v_total;
  end if;

  insert into aprobaciones_semanales (semana_id, decision, aprobado_por, fecha_aprobacion, comentarios, aprobado_por_id)
  values (v_sem.id, p_decision, v_por, p_fecha_aprobacion, v_com, auth.uid());

  update semanas set estado = p_decision where id = v_sem.id;
  update cambios
     set estado = case p_decision when 'Aprobada' then 'Aprobado' else 'Rechazado' end
   where semana_id = v_sem.id;
end $$;

-- =====================================================================
-- 5. VISTA DE DETALLE CON LA ETAPA (columnas nuevas al final)
-- =====================================================================
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
  c.estado,
  c.clasificacion_id,
  c.resultado_id,
  c.etapa,
  c.fecha_sesion,
  c.fecha_ejecucion
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
) ap on c.estado in ('Aprobado', 'Rechazado')
where public.mi_rol() in ('Aprobador', 'Administrador');

-- =====================================================================
-- 6. PERMISOS
-- =====================================================================
revoke execute on function public.avanzar_etapa(bigint, date, boolean, bigint, boolean, text) from public, anon;
revoke execute on function public.trg_cambios_etapa() from public, anon, authenticated;
grant  execute on function public.avanzar_etapa(bigint, date, boolean, bigint, boolean, text) to authenticated;

notify pgrst, 'reload schema';
