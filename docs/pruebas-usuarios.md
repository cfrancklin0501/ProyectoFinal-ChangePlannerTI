# Pruebas con usuarios · Semana 5

Validación del MVP de ChangePlanner TI en producción con una usuaria final.

- **App probada:** https://cfrancklin0501.github.io/ProyectoFinal-ChangePlannerTI/ (versión de la semana 4)
- **Fecha:** 15/11/2026
- **Modalidad:** la participante usó la app por su cuenta en producción y envió sus observaciones en 5 notas de voz de WhatsApp (unos 3 minutos en total). Las notas se transcribieron y se resumen abajo.

## Participantes

Sin nombres, solo perfil.

| Id | Perfil | Relación con el problema | Rol en la app | Dispositivo |
|---|---|---|---|---|
| P1 | Usuaria final del área de infraestructura/TI `[CONFIRMAR: puesto]` | Registra y da seguimiento a los cambios en el Excel actual | Administrador `[CONFIRMAR]` (es el único rol que puede registrar cambios) | `[COMPLETAR: computadora o celular]` |

**Roles que participaron:** Administrador (P1). No participó ninguna persona con el rol Aprobador ni Visualizador; queda para la segunda ronda (semana 8).

## Guion de tareas

Se pidió a la participante recorrer la app como lo haría en su trabajo:

| # | Tarea | Qué se espera |
|---|---|---|
| T1 | Iniciar sesión con la cuenta asignada | Entra y ve el tablero de bienvenida |
| T2 | Registrar un cambio real de su trabajo | El cambio queda guardado y aparece en la lista |
| T3 | Encontrar un cambio en **Cambios registrados** | Lo localiza sin recorrer toda la tabla |
| T4 | Revisar el tablero de bienvenida | Entiende los indicadores y el gráfico por área |
| T5 | Revisar el resumen semanal | Ve los totales de la semana y quién hizo cada cambio |

## Resultados por tarea

| Tarea | Resultado | Observaciones | Hallazgos |
|---|---|---|---|
| T1 Iniciar sesión | ✅ Completada | Sin comentarios; pudo entrar a las secciones protegidas | — |
| T2 Registrar un cambio | ⚠️ Completada con observaciones | El formulario pide en el registro datos que todavía no existen (resultado, confirmación); el proceso real va por etapas. Esperaba que el código de empleado llenara solo el nombre y el área | H1, H3 |
| T3 Encontrar un cambio | ⚠️ Completada con dificultad | No hay forma de buscar; pidió filtros por código de cambio, área y usuario | H2 |
| T4 Tablero de bienvenida | `[COMPLETAR: ¿lo revisó?]` | No hubo comentarios en sus mensajes | — |
| T5 Resumen semanal | `[COMPLETAR: ¿lo revisó?]` | No hubo comentarios en sus mensajes | — |

## Hallazgos

**Severidad:**
- **Bloqueante:** impide completar la tarea o hacerla como ocurre en el proceso real.
- **Grave:** la tarea se completa, pero con esfuerzo extra o riesgo de error.
- **Menor:** detalle de presentación o preferencia.

**Frecuencia:** participantes que lo mencionaron / participantes totales (y veces que lo mencionó).

| Id | Hallazgo | Evidencia (resumen de lo que dijo) | Severidad | Frecuencia | Issue | Semana |
|---|---|---|---|---|---|---|
| H1 | **El registro no sigue las etapas del proceso.** Al registrar se piden resultado (Exitoso/Fallido), confirmación y firmas, pero eso se conoce después: primero se ingresa la solicitud, luego se revisa y aprueba en sesión (se manda a firmar) y al final se ejecuta y se documenta el resultado | "La confirmación y el estatus si fue exitoso o fallido no lo llenamos al momento del registro, eso se hace como un llenado posterior". Propuso "etapa uno, registro; etapa dos, cuando se revisó en sesión y fue aprobado; etapa tres, cuando ya fue ejecutado" | **Bloqueante** | 1/1 (2 menciones) | `#[N]` | 5 · **corregido** |
| H2 | **No se puede buscar en Cambios registrados.** Hay que recorrer la tabla para encontrar un cambio | Pidió "un filtro por código de cambio, porque hay gente que se conoce su código", y también por área o por usuario | **Grave** | 1/1 (1 mención) | `#[N]` | 6 |
| H3 | **El código de empleado no completa los datos del solicitante.** Hay que escribir usuario y elegir área a mano aunque el empleado ya existe | "Si yo pongo mi código de empleado me va a reconocer cuál es mi nombre y mi área… eso se podría llenar en automático" | **Grave** | 1/1 (1 mención) | `#[N]` | 7 |

## Corrección del bloqueante H1

Se implementó el **registro por etapas** (migración `supabase/migrations/20261128000007_etapas_cambio.sql`):

1. **Registrado:** el formulario de registro ya no pide resultado, confirmación ni firmas. El cambio queda con resultado *Pendiente*.
2. **Aprobado en sesión:** en *Cambios registrados* → **Actualizar etapa**, se indica la fecha de la sesión y si ya está firmado.
3. **Ejecutado:** se indica la fecha de ejecución, el resultado (Exitoso, Fallido o Revertido) y la confirmación. Si fue fallido o revertido, se exige explicar qué pasó.

El servidor hace cumplir el orden: no se puede saltar etapas, el resultado solo existe en la etapa 3, y gerencia no puede aprobar una semana mientras tenga cambios sin ejecutar.

**Verificación en producción:** `[COMPLETAR después de publicar: registrar un cambio, pasarlo a etapa 2 y 3, y adjuntar captura]`.

## Decisión sobre la hipótesis

**Hipótesis (docs/vision.md):** *si el registro se hace en una web, el resumen semanal se genera en minutos en lugar de horas.*

**Decisión: se mantiene, con un ajuste.**

- **A favor:** la participante pudo registrar y consultar cambios en la web. Sus observaciones piden adaptar la app a su proceso (etapas, búsqueda, autocompletado), no volver al Excel.
- **El ajuste:** el registro tiene que seguir las tres etapas reales del cambio. Si no, los datos del resumen semanal quedan incompletos o se capturan mal. Ya está corregido.
- **Lo que falta probar:** no se midió el tiempo de preparar el resumen y solo participó una persona con el rol Administrador. La segunda hipótesis (*con una aprobación visible, gerencia aprueba más rápido*) sigue abierta porque no participó nadie de gerencia.
- **Siguiente paso:** en la semana 8, segunda ronda con al menos un Aprobador. Se medirá cuánto tarda en revisar y aprobar la semana en la app, comparado con el Excel.

## Priorización para las semanas 6 a 9

| Semana | Trabajo | Origen |
|---|---|---|
| 6 | Búsqueda y filtros en Cambios registrados (código de cambio / RFC / ID solicitud, área, usuario) | H2 · Grave |
| 7 | Autocompletar usuario y área a partir del código de empleado | H3 · Grave |
| 8 | Segunda ronda de pruebas: Aprobador y Administrador, midiendo el tiempo del resumen y la aprobación | Hipótesis abierta |
| 9 | Corregir lo que salga de la segunda ronda y cierre | Ronda 2 |

El texto de cada issue está en [issues-semana-5.md](issues-semana-5.md).
