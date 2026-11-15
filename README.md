# ChangePlanner TI

Aplicación web para registrar qué persona realiza cambios en la infraestructura de TI de la empresa, con un resumen semanal para gerencia y aprobación posterior.

**App en producción:** https://cfrancklin0501.github.io/ProyectoFinal-ChangePlannerTI/

Cada cambio pasa por tres etapas: **Registrado → Aprobado en sesión → Ejecutado**.

**Token de propiedad:** LEARN-CAP-9CCE709E

## Tecnologías
- HTML, CSS y JavaScript (sin frameworks).
- Supabase: PostgreSQL como base de datos y Supabase Auth para las cuentas, consumidos por su API REST.

## Roles
| Rol | Puede |
|---|---|
| Visualizador (por defecto al registrarse) | Ver el tablero de bienvenida y el resumen semanal |
| Aprobador | Además, ver el detalle de los cambios y aprobar o rechazar la semana |
| Administrador | Registrar cambios, actualizar su etapa, editarlos y eliminarlos; gestionar usuarios y roles |

Los permisos se verifican en el servidor. Detalle y cuentas de demostración en [docs/permisos.md](docs/permisos.md).

## Estructura
```
index.html                 Inicio: tablero gerencial (todos los roles)
login.html                 Iniciar sesión, crear cuenta, recuperar contraseña
restablecer.html           Nueva contraseña (enlace del correo de recuperación)
RegistrarCambio.html       Registrar cambio (Administrador)
CambiosRegistrados.html    Lista de cambios (Aprobador; Administrador edita y elimina)
CambiosSemanal.html        Resumen semanal y aprobación de gerencia
Usuarios.html              Usuarios y roles (Administrador)
Estilos.css                Estilos compartidos
js/                        config.js, auth.js, api.js y un script por página
supabase/migrations/       Esquema versionado (ejecutar en orden)
supabase/seed.sql          Datos de ejemplo para desarrollo
supabase/cuentas-demo.sql  Roles de las cuentas de demostración
docs/                      Documentación
```

## Puesta en marcha
1. En Supabase, abre **SQL Editor** y ejecuta en orden los archivos de `supabase/migrations/` (1 a 7).
2. (Solo desarrollo) Ejecuta `supabase/seed.sql` para cargar datos de ejemplo.
3. En **Authentication → URL Configuration** pon la URL pública del sitio en *Site URL* y agrega `https://TU-SITIO/login.html` y `https://TU-SITIO/restablecer.html` en *Redirect URLs*.
4. Crea las cuentas de demostración y ejecuta `supabase/cuentas-demo.sql`. Para tu propia cuenta, regístrate en la app y dale el rol Administrador desde el SQL Editor (está el ejemplo al final de ese archivo).
5. Copia la **URL del proyecto** y la **clave pública** (anon / publishable) en `js/config.js`. Nunca uses la clave `service_role` ni la contraseña de la base.
6. Publica los archivos estáticos en tu hosting con HTTPS.

## Documentación
- [Visión del proyecto](docs/vision.md)
- [Mapa de historias](docs/mapa-historias.md) · [Backlog](docs/backlog-historias.md) · [Plan](docs/plan.md)
- [Modelo de datos](docs/modelo-datos.md)
- [Permisos](docs/permisos.md)
- [Pruebas con usuarios](docs/pruebas-usuarios.md) · [Issues de la prueba](docs/issues-semana-5.md)
- Bitácoras: [semana 1](docs/bitacora/semana-1.md) · [semana 2](docs/bitacora/semana-2.md) · [semana 3](docs/bitacora/semana-3.md) · [semana 4](docs/bitacora/semana-4.md) · [semana 5](docs/bitacora/semana-5.md)
