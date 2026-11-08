# Plan · ChangePlannerTI

Aplicación web en HTML, CSS y JavaScript para registrar los cambios de infraestructura de TI, generar el resumen semanal para gerencia y dejar constancia de su aprobación.

## Meta por semana

| Semana  | Meta                       | Historias                   | Entregable verificable |

| 1       | Visión y base del proyecto | —                           | README con token, `docs/vision.md`, `index.html` inicial, release `semana-1` |

| 2       | Primera historia viva      | H1 (y base de H2)           | Mapa de historias, backlog de 16 issues, este plan, formulario publicado con HTTPS, release `semana-2` |

| 3       | Formulario funcional       | H2, H3, H4                  | Se capturan, validan y guardan cambios; sobreviven a recargar la página |

| 4       | MVP completo               | H5, H6                      | Lista y detalle de cambios: el analista ya puede usar la app de punta a punta |

| 5       | Resumen y aprobación       | H7 a H11                    | Gerencia elige una semana, ve el resumen y lo aprueba |

| 6       | Cierre y pulido            | H12 a H16 según tiempo      | Funciones del corte 3, pruebas manuales, documentación final y release de entrega |

Este plan asume 6 semanas. Si el curso tiene otra duración, las semanas 5 y 6 son las que se ajustan.

## Cómo se cubre el piso de la app completa

El **piso** es lo mínimo para que la app sea útil de verdad: un analista registra y consulta cambios (corte 1) y gerencia ve el resumen semanal y lo aprueba (corte 2). Eso queda terminado al final de la semana 5.

El **corte 3** (tipo de RFC, edición, exportar a PDF, rechazar con nota, catálogos) suma valor pero no es necesario para que la app funcione. Se hace en la semana 6 en orden de prioridad: primero H12 y H13, que completan los datos del Excel actual, y después H14 a H16 si alcanza el tiempo.

## Cómo se trabaja cada semana

- Una historia por vez: se mueve a "en curso", se implementa y se cierra con `Closes #N` en el commit.
- Commits pequeños y frecuentes, al menos 3 en cada ventana de 10 días, no todos al final.
- Despliegue en GitHub Pages después de cada historia terminada, para que producción siempre refleje el repo.
- Al cerrar la semana: bitácora en `docs/bitacora/semana-N.md` y etiqueta `semana-N`.

## Decisiones técnicas

- Persistencia inicial en `localStorage` del navegador. Si el tiempo lo permite, se evalúa un backend sencillo para compartir datos entre usuarios.
- Sin frameworks: JavaScript, HTML y CSS puros, para mantener el alcance manejable.
- Los campos del formulario salen de las columnas del Excel que se usa hoy.

## Riesgos

Riesgo
`localStorage` es por navegador y no permite que gerencia vea lo que registra el analista en otro equipo  

Mitigación 
Aceptarlo en el MVP y documentarlo; evaluar backend en la semana 6 

Riesgo
Tiempo insuficiente para el corte 3 

Mitigación
Está priorizado y es opcional; el piso queda cerrado en la semana 5 

Riesgo
Dejar los commits para el final

Mitigación
Una historia por vez con commit al cerrarla