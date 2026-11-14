-- ChangePlanner TI · Semana 4 · Cuentas de demostración (una por rol)
--
-- Paso 1 (en el panel de Supabase): Authentication → Users → Add user → Create new user.
--   Crea estas tres cuentas marcando "Auto Confirm User" y con la contraseña indicada:
--
--     visualizador.demo@changeplanner.test   Demo-Visual-2026
--     aprobador.demo@changeplanner.test      Demo-Aprueba-2026
--     admin.demo@changeplanner.test          Demo-Admin-2026
--
--   Al crearlas, el trigger al_crear_usuario les crea un perfil con rol Visualizador.
--
-- Paso 2: ejecuta este archivo en el SQL Editor para darles nombre y rol.
-- (Desde el SQL Editor no aplica exigir_rol, por eso aquí sí se puede cambiar el rol directo.)

update public.perfiles set nombre_completo = 'Valeria Visualizadora (demo)', rol = 'Visualizador', activo = true
 where lower(correo) = 'visualizador.demo@changeplanner.test';

update public.perfiles set nombre_completo = 'Sofía Flores (demo)', rol = 'Aprobador', activo = true
 where lower(correo) = 'aprobador.demo@changeplanner.test';

update public.perfiles set nombre_completo = 'Andrés Admin (demo)', rol = 'Administrador', activo = true
 where lower(correo) = 'admin.demo@changeplanner.test';

-- Comprobación: deben salir las tres cuentas con su rol
select correo, nombre_completo, rol, activo
from public.perfiles
where correo like '%.demo@changeplanner.test'
order by rol;

-- Para hacer Administrador a tu cuenta real (cámbiala por tu correo):
-- update public.perfiles set rol = 'Administrador' where lower(correo) = 'tu-correo@ejemplo.com';
