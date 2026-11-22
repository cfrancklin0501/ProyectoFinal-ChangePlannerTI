# Registro de decisiones · ChangePlanner TI

Cada archivo registra una decisión de arquitectura importante: el **contexto** que la provocó, la **decisión**, las **alternativas** que se descartaron y sus **consecuencias** (lo bueno y lo que cuesta). Una decisión aceptada no se edita: si cambia, se escribe una nueva que la reemplace y se marca la anterior como *Reemplazada por 00NN*.

| # | Decisión | Estado | Fecha |
|---|---|---|---|
| [0001](0001-sitio-estatico-con-supabase.md) | Sitio estático sin frameworks + Supabase como backend | Aceptada | 2026-11-14 |
| [0002](0002-permisos-en-la-base-de-datos.md) | Los permisos por rol se verifican en la base de datos | Aceptada | 2026-11-14 |
| [0003](0003-etapas-del-cambio-en-el-servidor.md) | El registro sigue tres etapas controladas por el servidor | Aceptada | 2026-11-15 |
| [0004](0004-busqueda-filtrada-en-el-servidor.md) | La búsqueda de cambios se filtra en el servidor | Aceptada | 2026-11-21 |

## Plantilla

```markdown
# 00NN · Título corto en forma de decisión

- **Estado:** Propuesta | Aceptada | Reemplazada por 00NN
- **Fecha:** AAAA-MM-DD
- **Relacionado:** issue, hallazgo, migración o archivo

## Contexto
Qué problema o fuerza obliga a decidir. Hechos, no opiniones.

## Decisión
Qué se decidió, en una o dos frases claras.

## Alternativas consideradas
- **Opción A:** por qué no.
- **Opción B:** por qué no.

## Consecuencias
- ✅ Lo que se gana.
- ⚠️ Lo que cuesta o el riesgo que se acepta.
```
