# Permisos · ChangePlanner TI

Desde la semana 4 la aplicación exige **iniciar sesión** (Supabase Auth) y cada cuenta tiene **un rol**. El rol se guarda en la tabla `perfiles` y **se verifica en el servidor** (PostgreSQL), no solo en el navegador: aunque alguien modifique el JavaScript o llame a la API a mano, la base de datos rechaza lo que su rol no permite.

## Roles

| Rol | Quién lo tiene | Para qué |
|---|---|---|
| **Visualizador** | Toda persona que crea su cuenta sola (rol por defecto) | Consultar el tablero de bienvenida y el resumen semanal |
| **Aprobador** | Gerencia; lo asigna un Administrador | Revisar los cambios de la semana y aprobar o rechazar la semana |
| **Administrador** | Responsables de TI; lo asigna otro Administrador | Registrar, editar y eliminar cambios; gestionar usuarios y roles |

Separación de funciones: el Administrador registra los cambios y el Aprobador los aprueba. Por eso el Administrador **no** puede aprobar semanas.

## Matriz de permisos

✅ permitido · ❌ denegado por el servidor

| Acción | Sin sesión | Visualizador | Aprobador | Administrador | Dónde lo verifica el servidor |
|---|---|---|---|---|---|
| Crear cuenta, iniciar sesión, recuperar contraseña | ✅ | ✅ | ✅ | ✅ | Supabase Auth |
| Ver tablero de bienvenida (KPI, gráfico por área, tabla dinámica) | ❌ | ✅ | ✅ | ✅ | vista `v_tablero` (filtro `mi_rol() is not null`) |
| Ver resumen semanal (totales y cambios por usuario) | ❌ | ✅ | ✅ | ✅ | vistas `v_resumen_semana`, `v_cambios_por_usuario` |
| Ver catálogos (áreas, clasificaciones…) | ❌ | ✅ | ✅ | ✅ | `grant select … to authenticated` + políticas RLS |
| Ver el detalle de los cambios y exportar CSV | ❌ | ❌ | ✅ | ✅ | vista `v_cambios_detalle` (filtro `mi_rol() in ('Aprobador','Administrador')`) |
| Aprobar o rechazar una semana | ❌ | ❌ | ✅ (solo con su propio usuario; aprobar exige todos los cambios en etapa Ejecutado) | ❌ | función `aprobar_semana` → `exigir_rol('Aprobador')` |
| Registrar un cambio (etapa 1, resultado Pendiente) | ❌ | ❌ | ❌ | ✅ | trigger `cambios_permisos` + trigger `cambios_etapa` |
| Actualizar etapa: 2 Aprobado en sesión / 3 Ejecutado (semana 5) | ❌ | ❌ | ❌ | ✅ | función `avanzar_etapa` → `exigir_rol('Administrador')` |
| Editar un cambio (no aprobado) | ❌ | ❌ | ❌ | ✅ | `actualizar_cambio` + trigger `cambios_permisos` |
| Eliminar un cambio (no aprobado, con motivo) | ❌ | ❌ | ❌ | ✅ | `eliminar_cambio` + trigger `cambios_permisos` |
| Ver su propio perfil | ❌ | ✅ | ✅ | ✅ | política RLS `perfiles_lectura` |
| Ver todos los usuarios | ❌ | ❌ | ❌ | ✅ | política RLS `perfiles_lectura` |
| Crear usuario y asignar rol | ❌ | ❌ | ❌ | ✅ | registro de Auth + `admin_guardar_usuario` |
| Cambiar nombre, rol o activar/desactivar usuario | ❌ | ❌ | ❌ | ✅ (no a sí mismo) | `admin_guardar_usuario` |
| Eliminar usuario | ❌ | ❌ | ❌ | ✅ (no a sí mismo) | `admin_eliminar_usuario` |

Páginas que muestra el menú a cada rol (solo comodidad; la seguridad es la tabla de arriba):

| Página | Visualizador | Aprobador | Administrador |
|---|---|---|---|
| `index.html` Inicio (tablero) | ✅ | ✅ | ✅ |
| `CambiosSemanal.html` Resumen semanal | ✅ (solo lectura) | ✅ (aprueba) | ✅ (solo lectura + CSV) |
| `CambiosRegistrados.html` Cambios registrados | ❌ | ✅ (lectura) | ✅ (edita y elimina) |
| `RegistrarCambio.html` Registrar cambio | ❌ | ❌ | ✅ |
| `Usuarios.html` Usuarios | ❌ | ❌ | ✅ |

## Cómo se verifica en el servidor

Todo está en [`supabase/migrations/20261121000006_autenticacion_roles.sql`](../supabase/migrations/20261121000006_autenticacion_roles.sql).

1. **Sin sesión no hay nada.** Se revocan todos los permisos del rol `anon` (clave pública sin sesión) sobre tablas, vistas y funciones. Un usuario con sesión usa el rol `authenticated`.
2. **El rol vive en la base.** `perfiles.rol` solo acepta `Visualizador`, `Aprobador` o `Administrador`. Al registrarse, el trigger `al_crear_usuario` crea el perfil **siempre** como Visualizador e ignora cualquier rol que se mande en los datos del registro. Nadie tiene `update` directo sobre `perfiles`; solo un Administrador cambia roles con `admin_guardar_usuario`.
3. **`mi_rol()`** devuelve el rol del usuario del token (`auth.uid()`), o `null` si la cuenta está desactivada.
4. **`exigir_rol(roles)`** lanza el error `42501` con un mensaje claro si el rol no está en la lista. Lo llaman todas las funciones de escritura y el trigger de `cambios`.
5. **Las vistas filtran por rol.** Como las vistas se ejecutan con permisos de su dueño, cada una lleva el filtro de `mi_rol()` dentro: un Visualizador que consulte `v_cambios_detalle` recibe 0 filas.
6. **El trigger `cambios_permisos`** protege la tabla `cambios` por cualquier camino: insertar, modificar o borrar exige Administrador. La única excepción es el cambio de la columna `estado` que hace `aprobar_semana` (que a su vez exige Aprobador).
7. **"Aprobado por" es el usuario real.** `aprobar_semana` rechaza la decisión si el nombre elegido no es el del usuario que inició sesión y guarda su id en `aprobaciones_semanales.aprobado_por_id`.
8. **Auditoría.** `historial_cambios.ejecutado_por` guarda el correo del usuario; los cambios eliminados quedan copiados en `cambios_eliminados` con motivo y responsable.
9. **Reglas de seguridad propias:** un Administrador no puede quitarse su rol, desactivarse ni eliminarse, y siempre debe quedar al menos un Administrador activo.

## Pruebas de permisos realizadas

Se probaron en una base PostgreSQL local con las 6 migraciones y en el navegador con cada cuenta de demostración:

| Prueba | Resultado esperado | Resultado |
|---|---|---|
| Consultar `v_resumen_semana` sin sesión | `permission denied` | ✅ |
| Visualizador consulta `v_cambios_detalle` | 0 filas | ✅ |
| Visualizador llama `aprobar_semana` desde la consola del navegador | "Tu rol (Visualizador) no tiene permiso…" | ✅ |
| Visualizador intenta `update perfiles set rol='Administrador'` | `permission denied` | ✅ |
| Registro con `rol: Administrador` en los metadatos | Queda como Visualizador | ✅ |
| Aprobador llama `registrar_cambio` desde la consola | "Tu rol (Aprobador) no tiene permiso…" | ✅ |
| Aprobador aprueba con el nombre de otra persona | "Solo puedes registrar la decisión con tu propio usuario" | ✅ |
| Aprobador aprueba con su usuario | Semana aprobada, `aprobado_por_id` guardado | ✅ |
| Administrador intenta aprobar una semana | Denegado (separación de funciones) | ✅ |
| Administrador edita / elimina un cambio aprobado | Denegado | ✅ |
| Administrador se quita su propio rol o se elimina | Denegado | ✅ |
| Administrador crea usuario con rol Aprobador | Cuenta creada con ese rol; su sesión no cambia | ✅ |

## Cuentas de demostración

| Rol | Correo | Contraseña |
|---|---|---|
| Visualizador | `visualizador.demo@changeplanner.test` | `Demo-Visual-2026` |
| Aprobador | `aprobador.demo@changeplanner.test` | `Demo-Aprueba-2026` |
| Administrador | `admin.demo@changeplanner.test` | `Demo-Admin-2026` |

Se crean como se indica en [`supabase/cuentas-demo.sql`](../supabase/cuentas-demo.sql). Son cuentas de demostración sobre datos ficticios: si la aplicación llega a usar datos reales, hay que borrarlas o cambiarles la contraseña, porque este repositorio es público.
