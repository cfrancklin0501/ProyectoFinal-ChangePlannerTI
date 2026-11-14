-- ChangePlanner TI · Semana 3 · Migración 5 de 5: seguridad (RLS y permisos)
-- Modelo: la web usa la clave pública (rol anon). Puede LEER catálogos y vistas,
-- y ESCRIBIR solo llamando a registrar_cambio y aprobar_semana. Nada de insert/update/delete directo.
-- Limitación conocida: sin login, cualquiera con la URL puede usar esas dos funciones (se resuelve con Supabase Auth).

alter table public.areas                  enable row level security;
alter table public.roles                  enable row level security;
alter table public.clasificaciones        enable row level security;
alter table public.ambitos_rfc            enable row level security;
alter table public.resultados_cambio      enable row level security;
alter table public.empleados              enable row level security;
alter table public.solicitudes            enable row level security;
alter table public.rfcs                   enable row level security;
alter table public.semanas                enable row level security;
alter table public.cambios                enable row level security;
alter table public.aprobaciones_semanales enable row level security;
alter table public.historial_cambios      enable row level security;

-- Se parte de cero: nadie escribe directo
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

-- Catálogos públicos de solo lectura (los usan las listas del formulario)
create policy "catalogo_areas_lectura"           on public.areas             for select to anon, authenticated using (true);
create policy "catalogo_clasificaciones_lectura" on public.clasificaciones   for select to anon, authenticated using (true);
create policy "catalogo_ambitos_lectura"         on public.ambitos_rfc       for select to anon, authenticated using (true);
create policy "catalogo_resultados_lectura"      on public.resultados_cambio for select to anon, authenticated using (true);
grant select on public.areas, public.clasificaciones, public.ambitos_rfc, public.resultados_cambio to anon, authenticated;

-- Vistas (se ejecutan con permisos del dueño; no exponen correo ni otros datos internos)
grant select on public.v_cambios_detalle, public.v_resumen_semana, public.v_cambios_por_usuario to anon, authenticated;

-- Únicas vías de escritura
grant execute on function public.registrar_cambio(date, text, text, bigint, text, text, bigint, text, text, bigint, bigint, boolean, boolean, text) to anon, authenticated;
grant execute on function public.aprobar_semana(int, int, text, text, date, text) to anon, authenticated;

-- Refresca la caché de la API de Supabase
notify pgrst, 'reload schema';
