# 0002 · Los permisos por rol se verifican en la base de datos

- **Estado:** Aceptada
- **Fecha:** 2026-11-14 (semana 4)
- **Relacionado:** [permisos.md](../permisos.md), `supabase/migrations/20261121000006_autenticacion_roles.sql`, `js/auth.js`

## Contexto
- Hay tres roles con permisos distintos: Visualizador, Aprobador y Administrador.
- Por la decisión [0001](0001-sitio-estatico-con-supabase.md) no hay un servidor propio entre el navegador y la base: la API REST de Supabase es pública y cualquiera con la clave pública puede llamarla desde la consola del navegador o con `curl`, sin pasar por las páginas.
- Ocultar un botón o una página no impide que alguien haga la petición directamente.

## Decisión
**El rol se comprueba en PostgreSQL en cada operación.** El rol vive en la tabla `perfiles`; la función `mi_rol()` lo lee a partir del usuario del token (`auth.uid()`), y:
- las **vistas** (`v_cambios_detalle`, `v_resumen_semana`, …) filtran por `mi_rol()` dentro de la propia vista;
- las **funciones** (`registrar_cambio`, `avanzar_etapa`, `aprobar_semana`, `admin_guardar_usuario`, …) llaman a `exigir_rol()` antes de hacer nada;
- un **trigger** sobre `cambios` bloquea escrituras directas a la tabla;
- se revocan los permisos por defecto y se concede solo lo necesario (RLS activado en todas las tablas).

En el navegador, `js/auth.js` oculta menús y botones solo como comodidad.

## Alternativas consideradas
- **Validar el rol solo en JavaScript:** sencillo, pero cualquiera lo salta desde la consola. Descartada.
- **Solo políticas RLS por tabla:** sirven para lecturas simples, pero las reglas de negocio (quién aprueba, orden de etapas, copia antes de eliminar) quedan más claras y probadas en funciones. Se usan ambas.
- **Rol dentro del token (custom claims de Supabase Auth):** evita una consulta, pero un cambio de rol no aplica hasta que el usuario renueve su sesión. Se prefirió leer `perfiles` en cada petición.

## Consecuencias
- ✅ Un Visualizador que intenta aprobar desde la consola recibe el error del servidor (probado en la semana 4).
- ✅ Los mensajes de `exigir_rol()` se muestran tal cual en la página, así el usuario entiende por qué no puede.
- ⚠️ Las vistas de PostgreSQL se ejecutan con los permisos de su dueño y se saltan RLS: cada vista nueva **debe** incluir el filtro por `mi_rol()`. Es una regla a revisar en cada pull request.
- ⚠️ Más lógica en SQL: hay que probarla con cuentas de cada rol (cuentas de demostración en `supabase/cuentas-demo.sql`).
- ⚠️ El SQL Editor de Supabase queda fuera de `exigir_rol()` para poder dar el primer rol de Administrador y hacer mantenimiento.
