# 0001 · Sitio estático sin frameworks + Supabase como backend

- **Estado:** Aceptada
- **Fecha:** 2026-11-14 (semana 3; el hosting se confirmó en la semana 4)
- **Relacionado:** [arquitectura.md](../arquitectura.md), [plan.md](../plan.md), `js/api.js`, `supabase/migrations/`

## Contexto
- El proyecto lo desarrolla una sola persona, en semanas cortas, y empezó en la semana 1 como HTML, CSS y JavaScript puros.
- Se necesitaba una base de datos real (semana 3), cuentas con roles (semana 4) y la app publicada con HTTPS en un dominio público.
- No hay presupuesto para servidores ni tiempo para mantener uno (parches, certificados, despliegues).
- Los datos son tabulares y relacionales (cambios, semanas, empleados, áreas, aprobaciones): vienen de una tabla de Excel.

## Decisión
Mantener el frontend como **sitio estático con HTML, CSS y JavaScript sin frameworks**, publicado en **GitHub Pages**, y usar **Supabase** como backend: PostgreSQL para los datos, su API REST (PostgREST) para leer y llamar funciones, y Supabase Auth para las cuentas. El navegador habla con Supabase con `fetch`, sin librerías externas.

## Alternativas consideradas
- **Backend propio (Node.js/Express) + base de datos en un servidor:** más control, pero hay que programar y mantener la API, la autenticación y el hosting del servidor. No cabe en el tiempo del curso.
- **Framework de frontend (React, Vue):** facilita pantallas complejas, pero obliga a un paso de compilación y a reescribir las páginas que ya existían; las pantallas actuales son formularios y tablas que no lo necesitan.
- **Firebase (Firestore):** también evita el servidor, pero es una base de documentos; las relaciones, los únicos y las restricciones del Excel se modelan mejor en SQL.
- **Seguir con Excel compartido:** es el problema que el proyecto quiere resolver (no hay control de quién cambia qué ni aprobación clara).

## Consecuencias
- ✅ Despliegue gratis y automático: cada merge a `main` se publica con HTTPS.
- ✅ El esquema está versionado en `supabase/migrations/` y las reglas viven junto a los datos.
- ✅ Sin dependencias ni compilación: cualquier persona del curso puede leer el código.
- ⚠️ Como no hay servidor propio, **toda regla importante tiene que estar en la base** (ver [0002](0002-permisos-en-la-base-de-datos.md)). La clave pública queda visible en `js/config.js`; eso es esperado, pero obliga a que la seguridad no dependa de ella.
- ⚠️ Dependencia de un proveedor (Supabase). Al ser PostgreSQL estándar, las migraciones se pueden llevar a otro servidor.
- ⚠️ Sin framework, el código de pantalla se repite un poco entre páginas; se mitiga con `js/api.js` y `js/auth.js` compartidos.
