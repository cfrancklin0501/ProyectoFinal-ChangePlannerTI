-- ChangePlanner TI · Semana 4 · Migración 6: autenticación, roles de la aplicación y permisos en el servidor
--
-- Qué cambia respecto a la semana 3:
--   * Cada cuenta de Supabase Auth tiene un PERFIL con su rol: Visualizador, Aprobador o Administrador.
--   * Quien se registra solo queda como Visualizador. Solo un Administrador puede cambiar roles.
--   * La clave pública SIN sesión (rol anon) ya no puede leer ni escribir nada.
--   * Cada lectura y cada escritura comprueba el rol EN LA BASE DE DATOS, no en el navegador.
--
-- Nuevas tablas: perfiles, cambios_eliminados  (14 tablas en total)
-- Requisito: haber ejecutado las migraciones 1 a 5.

-- =====================================================================
-- 1. PERFILES (uno por cada usuario de auth.users)
-- =====================================================================
create table public.perfiles (
  id              uuid        primary key references auth.users (id) on delete cascade,
  correo          text        not null,
  nombre_completo text        not null,
  rol             text        not null default 'Visualizador',
  activo          boolean     not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint perfiles_rol_valido      check (rol in ('Visualizador', 'Aprobador', 'Administrador')),
  constraint perfiles_nombre_longitud check (char_length(btrim(nombre_completo)) >= 3)
);
create unique index perfiles_correo_unico on public.perfiles (lower(correo));

create trigger perfiles_updated_at before update on public.perfiles
  for each row execute function public.set_updated_at();

-- Al registrarse alguien en Supabase Auth se crea su perfil. El rol SIEMPRE es Visualizador:
-- se ignora cualquier "rol" que el usuario intente mandar en los metadatos del registro.
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_nombre text := btrim(coalesce(new.raw_user_meta_data ->> 'nombre_completo', ''));
begin
  if char_length(v_nombre) < 3 then
    v_nombre := coalesce(new.email, 'Usuario nuevo');
  end if;
  insert into public.perfiles (id, correo, nombre_completo)
  values (new.id, coalesce(new.email, new.id::text), left(v_nombre, 80))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

create or replace function public.sincronizar_correo_perfil()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.perfiles set correo = new.email where id = new.id and new.email is not null;
  return new;
end $$;

create trigger al_cambiar_correo after update of email on auth.users
  for each row execute function public.sincronizar_correo_perfil();

-- Usuarios que ya existían antes de esta migración
insert into public.perfiles (id, correo, nombre_completo)
select u.id,
       coalesce(u.email, u.id::text),
       left(coalesce(nullif(btrim(u.raw_user_meta_data ->> 'nombre_completo'), ''), u.email, 'Usuario'), 80)
from auth.users u
on conflict (id) do nothing;

-- =====================================================================
-- 2. FUNCIONES DE APOYO PARA PERMISOS
-- =====================================================================

-- Rol del usuario que hace la petición (null si no hay sesión o si la cuenta está desactivada)
create or replace function public.mi_rol()
returns text language sql stable security definer set search_path = public as $$
  select p.rol from public.perfiles p where p.id = auth.uid() and p.activo
$$;

-- Lanza un error si el usuario de la API no tiene uno de los roles indicados.
-- Solo aplica a las peticiones que llegan por la API pública (anon / authenticated);
-- el SQL Editor de Supabase y la clave service_role quedan fuera para tareas de mantenimiento.
create or replace function public.exigir_rol(p_roles text[])
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if coalesce(auth.role(), '') not in ('anon', 'authenticated') then
    return;
  end if;
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para realizar esta acción.' using errcode = '42501';
  end if;
  if public.mi_rol() is null then
    raise exception 'Tu cuenta está desactivada. Contacta al administrador.' using errcode = '42501';
  end if;
  if not (public.mi_rol() = any (p_roles)) then
    raise exception 'Tu rol (%) no tiene permiso para realizar esta acción.', public.mi_rol() using errcode = '42501';
  end if;
end $$;

-- =====================================================================
-- 3. CAMBIOS: solo el Administrador crea, modifica o elimina
-- =====================================================================
-- Se aplica con un trigger para que la regla valga por cualquier camino (funciones o SQL).
-- Excepción: la aprobación semanal solo cambia la columna "estado"; esa la controla aprobar_semana.
create or replace function public.trg_cambios_permisos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE'
     and (to_jsonb(new) - 'estado' - 'updated_at') = (to_jsonb(old) - 'estado' - 'updated_at') then
    return new;
  end if;
  perform public.exigir_rol(array['Administrador']);
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end $$;

create trigger cambios_permisos before insert or update or delete on public.cambios
  for each row execute function public.trg_cambios_permisos();

-- El historial ahora guarda el correo de la persona que hizo el cambio
create or replace function public.trg_cambios_historial()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_quien text := coalesce((select correo from public.perfiles where id = auth.uid()), session_user::text);
begin
  insert into historial_cambios (cambio_id, accion, datos_anteriores, datos_nuevos, ejecutado_por)
  values (new.id, tg_op, case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new), v_quien);
  return null;
end $$;

-- Copia de los cambios eliminados (el historial se borra en cascada con el cambio)
create table public.cambios_eliminados (
  id               bigint generated always as identity primary key,
  cambio_id        bigint      not null,
  datos            jsonb       not null,
  motivo           text        not null,
  eliminado_por    text        not null,
  eliminado_por_id uuid        references public.perfiles (id) on delete set null,
  fecha            timestamptz not null default now(),
  constraint cambios_eliminados_motivo_longitud check (char_length(btrim(motivo)) >= 5)
);

-- Editar un cambio (Administrador). Un cambio de una semana aprobada no se puede editar (lo bloquea trg_cambios_antes).
create or replace function public.actualizar_cambio(
  p_id               bigint,
  p_actividad        text,
  p_clasificacion_id bigint,
  p_resultado_id     bigint,
  p_confirmacion     boolean,
  p_firmadas         boolean,
  p_observaciones    text
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_actividad text := btrim(coalesce(p_actividad, ''));
  v_obs       text := nullif(btrim(coalesce(p_observaciones, '')), '');
  v_requiere  boolean;
begin
  perform public.exigir_rol(array['Administrador']);

  if not exists (select 1 from cambios where id = p_id) then
    raise exception 'El cambio #% no existe.', p_id;
  end if;
  if char_length(v_actividad) < 10 then
    raise exception 'La actividad debe describirse con al menos 10 caracteres.';
  end if;
  select requiere_justificacion into v_requiere from clasificaciones where id = p_clasificacion_id;
  if not found then raise exception 'Selecciona una clasificación válida.'; end if;
  if not exists (select 1 from resultados_cambio where id = p_resultado_id) then
    raise exception 'Selecciona un resultado válido.';
  end if;
  if v_requiere and char_length(coalesce(v_obs, '')) < 10 then
    raise exception 'Este tipo de cambio requiere una justificación en Observaciones (mínimo 10 caracteres).';
  end if;

  update cambios
     set actividad        = v_actividad,
         clasificacion_id = p_clasificacion_id,
         resultado_id     = p_resultado_id,
         confirmacion     = coalesce(p_confirmacion, false),
         firmadas         = coalesce(p_firmadas, false),
         observaciones    = v_obs
   where id = p_id;
end $$;

-- Eliminar un cambio (Administrador). No se permite si ya fue aprobado; se guarda una copia con el motivo.
create or replace function public.eliminar_cambio(p_id bigint, p_motivo text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_cambio cambios%rowtype;
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_quien  text := coalesce((select correo from public.perfiles where id = auth.uid()), session_user::text);
begin
  perform public.exigir_rol(array['Administrador']);

  select * into v_cambio from cambios where id = p_id for update;
  if not found then raise exception 'El cambio #% no existe.', p_id; end if;
  if v_cambio.estado = 'Aprobado' then
    raise exception 'Un cambio aprobado por gerencia no se puede eliminar.';
  end if;
  if char_length(v_motivo) < 5 then
    raise exception 'Indica el motivo de la eliminación (mínimo 5 caracteres).';
  end if;

  insert into cambios_eliminados (cambio_id, datos, motivo, eliminado_por, eliminado_por_id)
  values (v_cambio.id, to_jsonb(v_cambio), v_motivo, v_quien, auth.uid());

  delete from cambios where id = p_id;
end $$;

-- =====================================================================
-- 4. APROBACIÓN SEMANAL: solo el Aprobador, y con su propio usuario
-- =====================================================================
alter table public.aprobaciones_semanales
  add column aprobado_por_id uuid references public.perfiles (id) on delete set null;

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
  v_sem    semanas%rowtype;
  v_por    text := btrim(coalesce(p_aprobado_por, ''));
  v_com    text := nullif(btrim(coalesce(p_comentarios, '')), '');
  v_total  int;
  v_perfil perfiles%rowtype;
begin
  perform public.exigir_rol(array['Aprobador']);

  -- Por la API, "Aprobado por" tiene que ser el propio usuario que inició sesión
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

  select count(*) into v_total from cambios where semana_id = v_sem.id;
  if v_total = 0 then raise exception 'La semana no tiene cambios para aprobar.'; end if;

  insert into aprobaciones_semanales (semana_id, decision, aprobado_por, fecha_aprobacion, comentarios, aprobado_por_id)
  values (v_sem.id, p_decision, v_por, p_fecha_aprobacion, v_com, auth.uid());

  update semanas set estado = p_decision where id = v_sem.id;
  update cambios
     set estado = case p_decision when 'Aprobada' then 'Aprobado' else 'Rechazado' end
   where semana_id = v_sem.id;
end $$;

-- Lista de aprobadores para el selector "Aprobado por" (sin correos)
create or replace function public.listar_aprobadores()
returns table (id uuid, nombre_completo text)
language sql stable security definer set search_path = public as $$
  select p.id, p.nombre_completo
  from public.perfiles p
  where p.rol = 'Aprobador' and p.activo and public.mi_rol() is not null
  order by p.nombre_completo
$$;

-- =====================================================================
-- 5. GESTIÓN DE USUARIOS (Administrador)
-- =====================================================================
-- Crear: la pantalla Usuarios usa el registro normal de Supabase Auth y luego asigna el rol con esta función.
create or replace function public.admin_guardar_usuario(
  p_id     uuid,
  p_nombre text,
  p_rol    text,
  p_activo boolean
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_admins int;
begin
  perform public.exigir_rol(array['Administrador']);

  if not exists (select 1 from perfiles where id = p_id) then
    raise exception 'El usuario no existe.';
  end if;
  if char_length(v_nombre) < 3 then
    raise exception 'El nombre debe tener al menos 3 caracteres.';
  end if;
  if p_rol not in ('Visualizador', 'Aprobador', 'Administrador') then
    raise exception 'El rol debe ser Visualizador, Aprobador o Administrador.';
  end if;
  if p_id = auth.uid() and (p_rol <> 'Administrador' or not coalesce(p_activo, true)) then
    raise exception 'No puedes quitarte el rol de Administrador ni desactivar tu propia cuenta.';
  end if;

  update perfiles
     set nombre_completo = v_nombre,
         rol             = p_rol,
         activo          = coalesce(p_activo, true)
   where id = p_id;

  select count(*) into v_admins from perfiles where rol = 'Administrador' and activo;
  if v_admins = 0 then
    raise exception 'Debe quedar al menos un Administrador activo.';
  end if;
end $$;

-- Eliminar: borra la cuenta de Supabase Auth (el perfil se borra en cascada)
create or replace function public.admin_eliminar_usuario(p_id uuid)
returns void
language plpgsql security definer set search_path = public, auth as $$
declare
  v_admins int;
begin
  perform public.exigir_rol(array['Administrador']);

  if p_id = auth.uid() then
    raise exception 'No puedes eliminar tu propia cuenta.';
  end if;
  if not exists (select 1 from perfiles where id = p_id) then
    raise exception 'El usuario no existe.';
  end if;

  delete from auth.users where id = p_id;

  select count(*) into v_admins from perfiles where rol = 'Administrador' and activo;
  if v_admins = 0 then
    raise exception 'Debe quedar al menos un Administrador activo.';
  end if;
end $$;

-- =====================================================================
-- 6. VISTAS DE LECTURA FILTRADAS POR ROL
-- =====================================================================
-- Las vistas se ejecutan con permisos del dueño, por eso el filtro de rol va dentro de cada vista.

-- Detalle de cambios: Aprobador y Administrador (se agregan al final los id para el formulario de edición)
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
  c.resultado_id
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

-- Resumen semanal: cualquier usuario con sesión y cuenta activa
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
where public.mi_rol() is not null
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
where public.mi_rol() is not null
group by s.anio, s.semana, e.id, e.usuario, a.id, a.nombre;

-- Tablero gerencial de la bienvenida: conteos agregados (sin actividades ni personas)
create or replace view public.v_tablero as
select
  c.fecha_ingreso,
  s.anio    as semana_anio,
  s.semana  as semana_num,
  a.nombre  as area,
  cl.nombre as clasificacion,
  rc.nombre as resultado,
  c.estado,
  count(*)::int as cambios
from public.cambios c
join public.semanas s            on s.id  = c.semana_id
join public.areas a              on a.id  = c.area_id
join public.clasificaciones cl   on cl.id = c.clasificacion_id
join public.resultados_cambio rc on rc.id = c.resultado_id
where public.mi_rol() is not null
group by c.fecha_ingreso, s.anio, s.semana, a.nombre, cl.nombre, rc.nombre, c.estado;

-- =====================================================================
-- 7. RLS Y PERMISOS
-- =====================================================================
alter table public.perfiles           enable row level security;
alter table public.cambios_eliminados enable row level security;

-- Cada usuario lee su propio perfil; el Administrador lee todos. Nadie escribe directo (solo por funciones).
create policy "perfiles_lectura" on public.perfiles
  for select to authenticated
  using (id = auth.uid() or public.mi_rol() = 'Administrador');

-- Los catálogos ya no son públicos: solo para usuarios con sesión
alter policy "catalogo_areas_lectura"           on public.areas             to authenticated;
alter policy "catalogo_clasificaciones_lectura" on public.clasificaciones   to authenticated;
alter policy "catalogo_ambitos_lectura"         on public.ambitos_rfc       to authenticated;
alter policy "catalogo_resultados_lectura"      on public.resultados_cambio to authenticated;

-- Se parte de cero otra vez (Supabase da permisos por defecto a los objetos nuevos)
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

grant select on public.areas, public.clasificaciones, public.ambitos_rfc, public.resultados_cambio to authenticated;
grant select on public.perfiles to authenticated;
grant select on public.v_cambios_detalle, public.v_resumen_semana, public.v_cambios_por_usuario, public.v_tablero
  to authenticated;

-- mi_rol se usa en la política de perfiles, por eso authenticated necesita ejecutarla
grant execute on function public.mi_rol() to authenticated;

-- Vías de escritura (cada una comprueba el rol por dentro)
grant execute on function public.registrar_cambio(date, text, text, bigint, text, text, bigint, text, text, bigint, bigint, boolean, boolean, text) to authenticated;
grant execute on function public.actualizar_cambio(bigint, text, bigint, bigint, boolean, boolean, text) to authenticated;
grant execute on function public.eliminar_cambio(bigint, text) to authenticated;
grant execute on function public.aprobar_semana(int, int, text, text, date, text) to authenticated;
grant execute on function public.listar_aprobadores() to authenticated;
grant execute on function public.admin_guardar_usuario(uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_eliminar_usuario(uuid) to authenticated;

notify pgrst, 'reload schema';
