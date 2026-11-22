# Bitácora · Semana 6 · Segundo flujo y decisiones

**Fecha de cierre:** `[COMPLETAR: fecha]`

## Objetivo de la semana
Documentar cómo está construida la app y por qué, y poner en producción un segundo flujo completo elegido a partir de la prueba con usuarios.

## Qué hice
- **Arquitectura documentada** en [docs/arquitectura.md](../arquitectura.md): diagrama de contexto (roles y sistemas externos), diagrama de contenedores (GitHub Pages, Supabase Auth, API REST, PostgreSQL), las seis capas del stack con lo que hace y lo que *no* hace cada una, un diagrama de secuencia de una búsqueda y la estructura de carpetas con sus convenciones.
- **Cuatro decisiones registradas** en [docs/decisiones/](../decisiones/) con contexto, decisión, alternativas y consecuencias:
  - [0001](../decisiones/0001-sitio-estatico-con-supabase.md) Sitio estático sin frameworks + Supabase.
  - [0002](../decisiones/0002-permisos-en-la-base-de-datos.md) Permisos por rol verificados en la base de datos.
  - [0003](../decisiones/0003-etapas-del-cambio-en-el-servidor.md) Registro por etapas controlado por el servidor.
  - [0004](../decisiones/0004-busqueda-filtrada-en-el-servidor.md) Búsqueda filtrada en el servidor.
- **Segundo flujo completo: buscar y filtrar cambios** en *Cambios registrados*. Lo elegí porque fue el hallazgo grave **H2** de la prueba con usuarios (la participante tenía que recorrer toda la tabla y pidió buscar por código, área y usuario):
  - Buscador por **código del cambio** (RFC, ID de solicitud o ID-RFC-BI, aunque se escriba solo una parte), **área**, **usuario o código de empleado**, **etapa** y **semana**.
  - Los filtros se combinan y se aplican en el servidor, así que se encuentra cualquier cambio (no solo los 500 más recientes) y la vista sigue comprobando el rol.
  - Contador "N cambios encontrados", mensaje "No hay cambios que coincidan con la búsqueda", aviso cuando la semana elegida esconde el resultado, y botón **Limpiar filtros**.
  - Busca al presionar Enter o *Buscar*, al cambiar una lista, o al dejar de escribir.
- **Trabajo por pull requests** enlazados a sus issues:
  - PR `feature/busqueda-cambios` → cierra el issue de H2.
  - PR `docs/arquitectura-decisiones` → cierra el issue de documentar la arquitectura.

## Recorrido del flujo en producción
| Paso | Qué hace el usuario | Qué pasa |
|---|---|---|
| 1 | Inicia sesión como Aprobador o Administrador y abre *Cambios registrados* | Ve la semana actual y el contador |
| 2 | Escribe parte de un RFC (por ejemplo `RFC-L`) | La tabla se reduce a los cambios cuyo RFC, ID de solicitud o ID-RFC-BI lo contienen |
| 3 | Elige un área y la etapa *Registrado* | Se aplican todos los filtros a la vez |
| 4 | Presiona *Ver todas las semanas* | Busca en todo el historial |
| 5 | Escribe un código que no existe | "No hay cambios que coincidan con la búsqueda" |
| 6 | Presiona *Limpiar filtros* | Vuelve a ver todos los cambios |

## Uso de IA
| Para qué | Herramienta | Qué hizo la IA | Qué hice yo / cómo lo verifiqué |
|---|---|---|---|
| Diagnóstico del repo | Claude | Leyó el repo, las pruebas con usuarios y el plan, y propuso tomar H2 como segundo flujo | Confirmé que era la prioridad de la semana 6 en `pruebas-usuarios.md` |
| Búsqueda y filtros | Claude | Escribió el formulario, los estilos y la lógica de filtros con la sintaxis de PostgREST (`ilike`, `and=(or(...))`) | `[COMPLETAR: probé cada filtro en producción con las cuentas de Aprobador y Administrador]` |
| Arquitectura | Claude | Redactó `arquitectura.md` con los diagramas Mermaid a partir del código y las migraciones | Revisé que los diagramas se vean en GitHub y que los nombres de archivos y funciones coincidan |
| Decisiones | Claude | Redactó las 4 decisiones a partir de lo que ya había decidido en semanas anteriores | Revisé que el contexto y las alternativas fueran las que realmente consideré |
| Textos de PR e issue | Claude | Propuso las descripciones de los pull requests y del issue de documentación | Los ajusté y los publiqué en GitHub |

**Lo que aprendí usando IA:** sirve mucho para leer todo el proyecto y documentarlo con nombres reales de archivos, pero hay que verificar en producción: la IA no podía iniciar sesión en la app, así que la prueba final de los filtros la hice yo.

## Decisiones y por qué
- **Filtrar en el servidor y no en el navegador:** la lista solo trae 500 filas; filtrando en el navegador un cambio viejo "no existiría" en la búsqueda (decisión 0004).
- **Sin migración nueva:** la vista `v_cambios_detalle` ya tenía todas las columnas y el filtro por rol.
- **Registrar decisiones pasadas:** 0001 a 0003 se tomaron en semanas anteriores; ahora quedan escritas con sus alternativas para no volver a discutirlas.

## Problemas y aprendizajes
- La sintaxis de filtros de PostgREST trata `,`, `(`, `)`, `*` y `"` como especiales. Si el usuario los escribe, la consulta se rompe; por eso se limpian antes de armar la URL.
- Con la semana actual seleccionada por defecto, buscar un código viejo no daba resultados. Se agregó un aviso que sugiere *Ver todas las semanas*.
- Separar el trabajo en dos ramas (código y documentación) hizo que cada pull request fuera fácil de revisar.

## Evidencias (completar)
- Búsqueda en producción por código, área, usuario y sin resultados: `[COMPLETAR: capturas]`
- Pull requests mezclados: `[COMPLETAR: #N búsqueda, #N documentación]`
- Issues cerrados: `[COMPLETAR: #N H2, #N documentación]`
- Release: `semana-6`

## Próximos pasos
- Semana 7: autocompletar usuario y área a partir del código de empleado (H3).
- Semana 8: segunda ronda de pruebas con un Aprobador, midiendo el tiempo de revisar y aprobar la semana.
- Si la tabla crece mucho: índice trigram para la búsqueda por código (decisión 0004).
