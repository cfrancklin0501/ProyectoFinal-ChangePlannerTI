# Bitácora · Semana 4 · Usuarios, sesión y permisos

**Fecha de cierre:** `[COMPLETAR: fecha]`

## Objetivo de la semana
Que solo entren personas con cuenta, que cada una tenga un rol y que el servidor haga cumplir lo que cada rol puede ver y hacer.

## Qué hice
- **Inicio y cierre de sesión, registro y recuperación de contraseña** con Supabase Auth, usando su API REST desde JavaScript sin librerías (`js/auth.js`, `login.html`, `restablecer.html`). La sesión se renueva sola antes de expirar.
- **Tres roles**: Visualizador (rol por defecto al registrarse), Aprobador y Administrador, guardados en la nueva tabla `perfiles`.
- **Permisos verificados en el servidor** con la migración `20261121000006_autenticacion_roles.sql`: sin sesión no se puede leer nada; las vistas filtran por rol; las funciones y un trigger sobre `cambios` llaman a `exigir_rol()`. Detalle en [`docs/permisos.md`](../permisos.md).
- **Pantalla de bienvenida gerencial** (`index.html`) basada en mi tablero de Excel de RFC: total de cambios, total ejecutado, tasa de éxito, % fallido, gráfico de cambios por área y resultado, y tabla dinámica (área × resultado, clasificación o estado), con filtros por fechas y área.
- **CRUD completo para el Administrador**: registrar, editar y eliminar cambios (con motivo, guardado en `cambios_eliminados`), y crear, editar rol/nombre/estado y eliminar usuarios (`Usuarios.html`).
- **Aprobación con usuario real**: el Aprobador elige su usuario en "Aprobado por" y el servidor comprueba que sea él; se guarda `aprobado_por_id`.
- **Cuentas de demostración** por rol (`supabase/cuentas-demo.sql`).
- Ordené el repositorio: los scripts pasaron de `docs/js/` a `js/` (las páginas los buscaban ahí), la página de registro de cambios pasó a `RegistrarCambio.html` e `index.html` es ahora la bienvenida. Subí las migraciones de la semana 3 que faltaban en el repositorio.

## Decisiones y por qué
- **El rol se comprueba en la base de datos, no en la página.** Ocultar un botón no protege nada; por eso todo pasa por vistas filtradas, funciones con `exigir_rol()` y un trigger.
- **Registro abierto pero con el rol mínimo.** Cualquiera puede crear su cuenta, pero solo ve el tablero y el resumen; el trigger ignora cualquier rol enviado en el registro.
- **El Administrador no aprueba.** Quien registra los cambios no debe aprobarlos (separación de funciones).
- **Eliminar deja rastro.** El historial se borra en cascada con el cambio, así que antes se guarda una copia con motivo y responsable.
- **El SQL Editor queda fuera de `exigir_rol()`** para poder dar el primer rol de Administrador y hacer mantenimiento.

## Problemas y aprendizajes
- En el repositorio los scripts estaban en `docs/js/` pero las páginas cargaban `js/…`, así que en producción las páginas no se conectaban a la base. Lo corregí moviendo la carpeta.
- Las vistas de PostgreSQL se ejecutan con los permisos de su dueño y se saltan RLS: el filtro de rol tiene que ir dentro de la vista.
- Supabase da permisos por defecto a todo objeto nuevo; la migración vuelve a revocar todo y concede solo lo necesario.
- El servicio de correo incluido en Supabase envía pocos correos por hora; para la demo las cuentas se crean confirmadas desde el panel.

## Evidencias (completar al publicar)
- Aplicación en producción (HTTPS): `[COMPLETAR: URL pública]`
- Prueba de inicio de sesión, registro y recuperación en producción: `[COMPLETAR: capturas]`
- Prueba de permisos (un Visualizador intentando aprobar desde la consola recibe el error del servidor): `[COMPLETAR: captura]`
- Release: `semana-4`

## Próximos pasos
- Tablas de activos de infraestructura y su relación con los cambios.
- Firmas digitales por cambio (tabla `firmas`) en lugar del campo Sí/No.
- Pruebas automáticas de los permisos.
