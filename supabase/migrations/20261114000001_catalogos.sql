-- ChangePlanner TI · Semana 3 · Migración 1 de 5: catálogos (datos de referencia)
-- Tablas: areas, roles, clasificaciones, ambitos_rfc, resultados_cambio

create table public.areas (
  id          bigint generated always as identity primary key,
  codigo      text        not null,                 -- "ID Área" del Excel
  nombre      text        not null,
  activa      boolean     not null default true,
  created_at  timestamptz not null default now(),
  constraint areas_codigo_unico    unique (codigo),
  constraint areas_nombre_unico    unique (nombre),
  constraint areas_codigo_no_vacio check (char_length(btrim(codigo)) > 0),
  constraint areas_nombre_no_vacio check (char_length(btrim(nombre)) > 0)
);

create table public.roles (
  id          bigint generated always as identity primary key,
  nombre      text not null,
  descripcion text,
  constraint roles_nombre_unico unique (nombre)
);

create table public.clasificaciones (
  id                     bigint generated always as identity primary key,
  nombre                 text    not null,
  descripcion            text,
  requiere_justificacion boolean not null default false,
  constraint clasificaciones_nombre_unico unique (nombre)
);

create table public.ambitos_rfc (
  id     bigint generated always as identity primary key,
  nombre text not null,
  constraint ambitos_rfc_nombre_unico unique (nombre)
);

create table public.resultados_cambio (
  id       bigint generated always as identity primary key,
  nombre   text    not null,
  es_final boolean not null default true,
  constraint resultados_cambio_nombre_unico unique (nombre)
);

-- Datos de referencia (necesarios para que la app funcione, también en producción)
insert into public.roles (nombre, descripcion) values
  ('Solicitante', 'Pide o autoriza el cambio'),
  ('Ejecutor',    'Realiza el cambio en la infraestructura'),
  ('Aprobador',   'Gerencia: aprueba el resumen semanal')
on conflict (nombre) do nothing;

insert into public.clasificaciones (nombre, descripcion, requiere_justificacion) values
  ('Estándar',   'Cambio repetitivo, de bajo riesgo y preaprobado', false),
  ('Normal',     'Cambio planificado que sigue el flujo regular',   false),
  ('Emergencia', 'Cambio urgente para restaurar o evitar una caída', true)
on conflict (nombre) do nothing;

insert into public.ambitos_rfc (nombre) values ('Local'), ('Regional')
on conflict (nombre) do nothing;

insert into public.resultados_cambio (nombre, es_final) values
  ('Pendiente', false), ('Exitoso', true), ('Fallido', true), ('Revertido', true)
on conflict (nombre) do nothing;

insert into public.areas (codigo, nombre) values
  ('A01', 'Redes y Comunicaciones'),
  ('A02', 'Seguridad Informática'),
  ('A03', 'Servidores e Infraestructura'),
  ('A04', 'Bases de Datos'),
  ('A05', 'Soporte Técnico'),
  ('A06', 'Telefonía y Colaboración')
on conflict (codigo) do nothing;
