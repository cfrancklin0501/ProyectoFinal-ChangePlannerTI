-- ChangePlanner TI · Semana 3 · Migración 2 de 5: personas y referencias externas
-- Tablas: empleados, solicitudes, rfcs

-- Función genérica para mantener updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create table public.empleados (
  id              bigint generated always as identity primary key,
  codigo_empleado text,                              -- opcional en el Excel original
  usuario         text        not null,
  nombre_completo text,
  correo          text,
  area_id         bigint      not null references public.areas (id) on delete restrict,
  rol_id          bigint      not null references public.roles (id) on delete restrict,
  activo          boolean     not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint empleados_codigo_unico     unique (codigo_empleado),
  constraint empleados_usuario_no_vacio check (char_length(btrim(usuario)) > 0),
  constraint empleados_correo_formato   check (correo is null or correo ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);
create unique index empleados_usuario_unico on public.empleados (lower(usuario));
create index empleados_area_idx on public.empleados (area_id);

create trigger empleados_updated_at before update on public.empleados
  for each row execute function public.set_updated_at();

create table public.solicitudes (
  id               bigint generated always as identity primary key,
  codigo_solicitud text        not null,             -- "ID Solicitud" del Excel
  created_at       timestamptz not null default now(),
  constraint solicitudes_codigo_unico    unique (codigo_solicitud),
  constraint solicitudes_codigo_no_vacio check (char_length(btrim(codigo_solicitud)) > 0)
);

create table public.rfcs (
  id         bigint generated always as identity primary key,
  codigo_rfc text        not null,                   -- "RFC" del Excel
  ambito_id  bigint      not null references public.ambitos_rfc (id) on delete restrict,
  id_rfc_bi  text,                                   -- "ID-RFC-BI" del Excel
  created_at timestamptz not null default now(),
  constraint rfcs_codigo_unico    unique (codigo_rfc),
  constraint rfcs_codigo_no_vacio check (char_length(btrim(codigo_rfc)) > 0)
);
