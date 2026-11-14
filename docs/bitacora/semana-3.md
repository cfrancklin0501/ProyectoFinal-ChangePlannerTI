# Bitácora · Semana 3 · Datos reales

**Fecha de cierre:** 2026-11-14

## Objetivo de la semana
Pasar de páginas HTML sin datos a una aplicación que guarda y lee información en una base de datos real (Supabase / PostgreSQL), con el flujo central funcionando en producción.

## Qué hice
- Diseñé el modelo de datos del producto completo (24 tablas) y documenté las 12 del núcleo en [`docs/modelo-datos.md`](../modelo-datos.md), con diagrama Mermaid, diccionario de datos y comportamiento al borrar.
- Escribí 5 migraciones versionadas en `supabase/migrations/`: catálogos, empleados y referencias, núcleo (semanas, cambios, aprobaciones, historial), vistas y funciones, y seguridad.
- Creé un script de datos semilla realista en `supabase/seed.sql` (9 empleados ficticios, 17 cambios repartidos en 3 semanas, una semana ya aprobada).
- Conecté las tres páginas a la base con JavaScript (`js/`): el formulario registra cambios, la lista los muestra y el resumen semanal calcula totales y permite aprobar o rechazar la semana, exportar CSV e imprimir.
- Puse las reglas de negocio en la base de datos (restricciones, triggers y funciones) y la aplicación muestra sus mensajes de error de forma clara.

## Decisiones y por qué
- **Supabase como base de datos:** PostgreSQL administrado, con API lista y HTTPS incluido.
- **Escritura solo por funciones (`registrar_cambio`, `aprobar_semana`):** las validaciones y la transacción viven en un solo lugar y la clave pública no puede tocar las tablas directamente.
- **Área guardada en cada cambio:** si un empleado cambia de área, el histórico no se altera.
- **Estado del cambio derivado de la semana:** gerencia aprueba la semana completa, así que "Aprobado por" y "Fecha de aprobación" se leen de `aprobaciones_semanales` y no se repiten en cada fila.
- **Listas desplegables desde la base** (área, clasificación, resultado, Local/Regional) en lugar de texto libre, para evitar áreas duplicadas por errores de escritura.
- **Fechas en hora local del navegador**, no en UTC, para que registrar un cambio por la noche no caiga en "fecha futura".

## Problemas y aprendizajes
- El archivo se llamaba `Index.html`, pero los enlaces apuntaban a `index.html`. En un servidor Linux esa diferencia rompe la página de inicio, así que lo renombré a `index.html`.
- Sin inicio de sesión, la clave pública permite usar las dos funciones de escritura. Lo dejé documentado como limitación y queda para la semana de autenticación.
- Mostrar datos escritos por usuarios en las tablas exige `textContent` (no `innerHTML`) para evitar inyección de HTML.

## Evidencias (completar al publicar)
- Repositorio: https://github.com/cfrancklin0501/ProyectoFinal-ChangePlannerTI
- Aplicación en producción (HTTPS): `[COMPLETAR: URL pública]`
- Flujo probado en producción: registrar un cambio y ver el resumen semanal. `[COMPLETAR: fecha y captura]`
- Release: `semana-3`

## Próximos pasos
- Inicio de sesión con Supabase Auth y roles reales (el "Aprobado por" pasará a ser un empleado).
- Tablas de activos de infraestructura y su relación con los cambios.
- Pruebas automáticas de las reglas de negocio.
