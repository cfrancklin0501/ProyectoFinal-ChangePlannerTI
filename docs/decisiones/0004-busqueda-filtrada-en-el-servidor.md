# 0004 · La búsqueda de cambios se filtra en el servidor

- **Estado:** Aceptada
- **Fecha:** 2026-11-21 (semana 6)
- **Relacionado:** hallazgo H2 de [pruebas-usuarios.md](../pruebas-usuarios.md), `js/registrados.js`, vista `v_cambios_detalle`

## Contexto
- En la prueba con usuarios la participante tuvo que recorrer toda la tabla para encontrar un cambio. Pidió buscar por código de cambio ("hay gente que se conoce su código"), por área y por usuario (hallazgo **grave** H2).
- La lista de Cambios registrados ya pedía máximo 500 filas a la vista `v_cambios_detalle`. Con el uso real, la tabla de cambios crece cada semana.
- El "código" del cambio puede ser el RFC, el ID de solicitud o el ID-RFC-BI, y la gente suele recordar solo una parte.

## Decisión
Los filtros (código, área, usuario o código de empleado, etapa y semana) se envían como **parámetros de PostgREST** y los resuelve PostgreSQL sobre la vista `v_cambios_detalle`:
- código y usuario usan `ilike` con comodines (*contiene*) sobre varias columnas, combinados con `and=(or(...),or(...))`;
- área y etapa usan igualdad (`eq`);
- el texto escrito se limpia de los caracteres con significado en la sintaxis de filtros (`* % " ( ) , \`);
- el texto busca al dejar de escribir (400 ms) y se descartan respuestas que lleguen tarde.

## Alternativas consideradas
- **Traer todo y filtrar en el navegador:** instantáneo con pocos datos, pero el límite de 500 filas haría que un cambio viejo "no exista" en la búsqueda, y cada visita descargaría toda la tabla.
- **Una función `buscar_cambios(...)` en SQL:** más control (por ejemplo, ordenar por relevancia), pero requiere migración y duplicaría el filtro por rol que la vista ya tiene. Se puede adoptar más adelante si la búsqueda se complica.
- **Búsqueda de texto completo (`tsvector`) o índices trigram:** útiles con miles de registros; hoy el volumen no lo justifica.

## Consecuencias
- ✅ La búsqueda encuentra cualquier cambio, no solo los 500 más recientes, y la vista sigue aplicando el permiso por rol.
- ✅ No hizo falta migración: se reutilizó la vista existente.
- ⚠️ `ilike '%texto%'` no usa índices normales; si la tabla llega a decenas de miles de cambios conviene un índice trigram (`pg_trgm`) en las columnas de código.
- ⚠️ Armar la URL de filtros a mano exige limpiar bien el texto del usuario; esa limpieza está en `limpiarTexto()` de `js/registrados.js`.
