# 0003 · El registro sigue tres etapas controladas por el servidor

- **Estado:** Aceptada
- **Fecha:** 2026-11-15 (semana 5)
- **Relacionado:** hallazgo H1 de [pruebas-usuarios.md](../pruebas-usuarios.md), `supabase/migrations/20261128000007_etapas_cambio.sql`, función `avanzar_etapa`

## Contexto
- La primera versión copiaba las columnas del Excel y pedía todo al registrar: resultado (Exitoso/Fallido), confirmación y firmas.
- En la prueba con usuarios (semana 5) la participante explicó que esos datos se conocen después: primero se registra, luego se aprueba en sesión y se firma, y al final se ejecuta y se documenta el resultado. Fue el hallazgo **bloqueante** H1.
- Si el formulario obliga a llenar un resultado que aún no existe, el resumen semanal muestra datos inventados.

## Decisión
Cada cambio tiene una **etapa**: *Registrado → Aprobado en sesión → Ejecutado*. Solo se avanza con la función `avanzar_etapa` y el servidor hace cumplir el orden: no se saltan etapas, el resultado solo existe en la etapa 3, un resultado *Fallido* o *Revertido* exige explicación, y gerencia no puede aprobar una semana con cambios sin ejecutar.

## Alternativas consideradas
- **Dejar los campos opcionales en un solo formulario:** más rápido de hacer, pero nada impide cerrar un cambio sin resultado o con fechas fuera de orden.
- **Controlar las etapas solo en la página:** la regla se saltaría llamando a la API (ver [0002](0002-permisos-en-la-base-de-datos.md)).
- **Una tabla de eventos por etapa:** da un historial más rico, pero era más trabajo del que pedía el bloqueante; el historial actual (`historial_cambios`) ya guarda cada modificación.

## Consecuencias
- ✅ El sistema sigue el proceso real y el resumen semanal no tiene resultados inventados.
- ✅ Los cambios anteriores se ubicaron en su etapa según lo que tenían capturado (migración 7).
- ⚠️ La aprobación semanal depende de que el Administrador actualice las etapas a tiempo; el resumen muestra cuántos faltan.
- ⚠️ Si el proceso agrega una etapa, hace falta una migración nueva y ajustar `avanzar_etapa`.
