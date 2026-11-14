-- ChangePlanner TI · Semana 3 · Migración 3 de 5: núcleo del negocio
-- Tablas: semanas, cambios, aprobaciones_semanales, historial_cambios (+ triggers)

create table public.semanas (
  id           bigint generated always as identity primary key,
  anio         smallint    not null,                 -- año ISO
  semana       smallint    not null,                 -- semana ISO (lunes a domingo)
  fecha_inicio date        not null,
  fecha_fin    date        not null,
  estado       text        not null default 'Abierta',
  created_at   timestamptz not null default now(),
  constraint semanas_anio_semana_unica  unique (anio, semana),
  constraint semanas_estado_valido      check (estado in ('Abierta', 'Aprobada', 'Rechazada')),
  constraint semanas_semana_rango       check (semana between 1 and 53),
  constraint semanas_fechas_coherentes  check (fecha_fin = fecha_inicio + 6)
);

-- Devuelve el id de la semana ISO de una fecha; la crea si no existe.
create or replace function public.obtener_o_crear_semana(p_fecha date)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_inicio date := p_fecha - (extract(isodow from p_fecha)::int - 1);
  v_anio   int  := extract(isoyear from p_fecha);
  v_sem    int  := extract(week from p_fecha);
  v_id     bigint;
begin
  select id into v_id from semanas where anio = v_anio and semana = v_sem;
  if v_id is null then
    insert into semanas (anio, semana, fecha_inicio, fecha_fin)
    values (v_anio, v_sem, v_inicio, v_inicio + 6)
    on conflict (anio, semana) do nothing
    returning id into v_id;
    if v_id is null then
      select id into v_id from semanas where anio = v_anio and semana = v_sem;
    end if;
  end if;
  return v_id;
end $$;

create table public.cambios (
  id               bigint generated always as identity primary key,
  fecha_ingreso    date        not null,
  empleado_id      bigint      not null references public.empleados (id)         on delete restrict,
  area_id          bigint      not null references public.areas (id)             on delete restrict, -- área al momento del cambio
  solicitud_id     bigint      references public.solicitudes (id)                on delete set null,
  rfc_id           bigint      references public.rfcs (id)                       on delete set null,
  actividad        text        not null,
  clasificacion_id bigint      not null references public.clasificaciones (id)   on delete restrict,
  resultado_id     bigint      not null references public.resultados_cambio (id) on delete restrict,
  confirmacion     boolean     not null default false,
  firmadas         boolean     not null default false,
  observaciones    text,
  semana_id        bigint      not null references public.semanas (id)           on delete restrict,
  estado           text        not null default 'Por aprobar',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint cambios_actividad_longitud check (char_length(btrim(actividad)) >= 10),
  constraint cambios_estado_valido      check (estado in ('Por aprobar', 'Aprobado', 'Rechazado'))
);
create index cambios_semana_idx   on public.cambios (semana_id);
create index cambios_empleado_idx on public.cambios (empleado_id);
create index cambios_fecha_idx    on public.cambios (fecha_ingreso);

-- Reglas que se aplican siempre, también si alguien inserta directo por SQL
create or replace function public.trg_cambios_antes()
returns trigger language plpgsql as $$
declare
  v_sem semanas%rowtype;
begin
  if tg_op = 'INSERT' or new.fecha_ingreso is distinct from old.fecha_ingreso then
    if new.fecha_ingreso > current_date then
      raise exception 'La fecha de ingreso no puede ser futura.';
    end if;
    new.semana_id := public.obtener_o_crear_semana(new.fecha_ingreso);
    select * into v_sem from public.semanas where id = new.semana_id;
    if v_sem.estado = 'Aprobada' then
      raise exception 'La semana % de % ya fue aprobada por gerencia; no se pueden registrar más cambios en ella.',
        v_sem.semana, v_sem.anio;
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if old.estado = 'Aprobado' and new.estado = 'Aprobado' then
      raise exception 'Un cambio aprobado por gerencia no se puede modificar.';
    end if;
    new.updated_at := now();
  end if;
  return new;
end $$;

create trigger cambios_antes before insert or update on public.cambios
  for each row execute function public.trg_cambios_antes();

create table public.aprobaciones_semanales (
  id               bigint generated always as identity primary key,
  semana_id        bigint      not null references public.semanas (id) on delete cascade,
  decision         text        not null,
  aprobado_por     text        not null,             -- texto libre por ahora; pasará a empleado con login
  fecha_aprobacion date        not null,
  comentarios      text,
  created_at       timestamptz not null default now(),
  constraint aprobaciones_decision_valida    check (decision in ('Aprobada', 'Rechazada')),
  constraint aprobaciones_aprobador_longitud check (char_length(btrim(aprobado_por)) >= 3),
  constraint aprobaciones_rechazo_con_comentario
    check (decision = 'Aprobada' or char_length(btrim(coalesce(comentarios, ''))) >= 5)
);
create index aprobaciones_semana_idx on public.aprobaciones_semanales (semana_id);

create table public.historial_cambios (
  id               bigint generated always as identity primary key,
  cambio_id        bigint      not null references public.cambios (id) on delete cascade,
  accion           text        not null,
  datos_anteriores jsonb,
  datos_nuevos     jsonb       not null,
  ejecutado_por    text        not null default current_user,
  fecha            timestamptz not null default now(),
  constraint historial_accion_valida check (accion in ('INSERT', 'UPDATE'))
);
create index historial_cambio_idx on public.historial_cambios (cambio_id);

create or replace function public.trg_cambios_historial()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into historial_cambios (cambio_id, accion, datos_anteriores, datos_nuevos)
  values (new.id, tg_op, case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return null;
end $$;

create trigger cambios_historial after insert or update on public.cambios
  for each row execute function public.trg_cambios_historial();
