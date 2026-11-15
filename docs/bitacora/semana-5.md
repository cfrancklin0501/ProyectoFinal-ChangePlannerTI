# Bitácora · Semana 5 · MVP con usuarios reales

**Fecha de cierre:** `[COMPLETAR: fecha]`

## Objetivo de la semana
Poner el MVP en manos de una usuaria real, escuchar qué le estorba y corregir lo que bloquea su trabajo.

## Qué hice
- **Publiqué el MVP en producción** con GitHub Pages (HTTPS): https://cfrancklin0501.github.io/ProyectoFinal-ChangePlannerTI/ y configuré Supabase Auth con esa dirección para el registro y la recuperación de contraseña.
- **Prueba con una usuaria final** (P1, área de infraestructura) que registra cambios hoy en Excel. Usó la app en producción y mandó sus observaciones en notas de voz. Resultados, hallazgos y decisión en [docs/pruebas-usuarios.md](../pruebas-usuarios.md).
- **Encontré 3 hallazgos:** 1 bloqueante (el registro no sigue las etapas del proceso) y 2 graves (no hay búsqueda en Cambios registrados; el código de empleado no completa los datos). Creé un issue para cada uno ([textos](../issues-semana-5.md)).
- **Corregí el bloqueante:** registro por etapas *Registrado → Aprobado en sesión → Ejecutado* (migración `20261128000007_etapas_cambio.sql`):
  - El formulario de registro ya no pide resultado, confirmación ni firmas.
  - Nuevo botón **Actualizar etapa** en Cambios registrados, con fecha de sesión, firmas, fecha de ejecución, resultado y confirmación.
  - El servidor no deja saltar etapas, el resultado solo existe en la etapa 3, un fallido o revertido exige explicación, y gerencia no puede aprobar una semana con cambios sin ejecutar.
  - Los cambios que ya existían se ubicaron en su etapa según lo que tenían capturado.

## Decisión sobre la hipótesis
**Se mantiene, con un ajuste:** la web sirve para registrar y consultar, pero solo si sigue las etapas reales del cambio. Falta medir el tiempo del resumen semanal y probar con gerencia (Aprobador); eso queda para la segunda ronda, en la semana 8.

## Qué aprendí
- Copié las columnas del Excel tal cual y asumí que todo se llenaba en un solo momento. En el proceso real el Excel se va completando por partes. La prueba lo mostró en el primer uso.
- Una sola participante ya da hallazgos útiles, pero no alcanza para validar la parte de gerencia.
- Pedir las observaciones por notas de voz fue cómodo para ella; para la próxima ronda conviene una sesión guiada para medir tiempos.

## Evidencias (completar)
- Prueba del registro por etapas en producción (etapa 1 → 2 → 3): `[COMPLETAR: capturas]`
- Gerencia intentando aprobar una semana con cambios sin ejecutar (mensaje del servidor): `[COMPLETAR: captura]`
- Issues creados: `[COMPLETAR: #N, #N, #N]`
- Release: `semana-5`

## Próximos pasos
- Semana 6: búsqueda y filtros en Cambios registrados (H2).
- Semana 7: autocompletar usuario y área por código de empleado (H3).
- Semana 8: segunda ronda de pruebas con Aprobador, midiendo tiempos.
- Semana 9: corregir lo que salga de la segunda ronda y cierre.
