# Visión: ChangePlanner TI

## Problema
Los cambios en la infraestructura se registran hoy en una hoja de Excel. No hay una vista clara de quién hizo qué, el seguimiento de aprobaciones es manual y armar el resumen semanal para gerencia toma tiempo.

## Evidencia
- Registro actual en Excel con 17 columnas (fecha, usuario, área, RFC, actividad, resultado, aprobado por, observaciones, etc.).
- El resumen para gerencia se prepara a mano cada semana.
- (Agregá aquí un dato propio: cuántos cambios por semana, cuánto tiempo toma el resumen, algún error que haya pasado.)

## Lean Canvas
- **Problema:** registro disperso, aprobaciones difíciles de rastrear, reportes manuales.
- **Segmento de clientes:** equipos de infraestructura/TI y su gerencia.
- **Propuesta de valor:** registrar cambios en un solo lugar y generar el resumen semanal listo para aprobar.
- **Solución:** web con formulario de cambios, listado filtrable y resumen semanal.
- **Canales:** acceso interno por navegador.
- **Fuentes de ingreso:** uso interno (ahorro de tiempo y trazabilidad).
- **Estructura de costos:** tiempo de desarrollo, hosting gratuito.
- **Métricas clave:** cambios registrados por semana, tiempo para generar el resumen.
- **Ventaja diferencial:** adaptada al flujo real de RFC y aprobación de la empresa.

## Hipótesis
- Si el registro se hace en una web, el resumen semanal se genera en minutos en lugar de horas.
- Si hay un campo de aprobación visible, gerencia aprueba más rápido.

## Alcance
**Incluye (MVP):** formulario para añadir cambios, tabla de cambios, resumen semanal.
**No incluye (por ahora):** login, base de datos en servidor, notificaciones por correo.
