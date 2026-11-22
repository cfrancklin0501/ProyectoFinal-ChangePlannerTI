# Issues de la prueba con usuarios · Semana 5

Texto listo para crear cada issue en GitHub (pestaña **Issues → New issue**). Después de crearlos, anota su número en la columna *Issue* de [pruebas-usuarios.md](pruebas-usuarios.md).

Etiquetas sugeridas: `prueba-usuarios`, la severidad (`bloqueante` o `grave`) y la semana (`semana-5`, `semana-6`, …).

---

## 1. [Bloqueante] Registrar los cambios por etapas: registro, aprobación en sesión y ejecución

**Etiquetas:** `prueba-usuarios`, `bloqueante`, `semana-5`
**Hallazgo:** H1 · frecuencia 1/1 (2 menciones)

**Problema**
Al registrar un cambio se piden resultado, confirmación y firmas, pero en el proceso real esos datos se conocen después. Primero se ingresa la solicitud, luego se revisa y aprueba en sesión (y se manda a firmar), y al final se ejecuta y se documenta el resultado.

**Historia**
Como administrador de cambios quiero registrar el cambio y luego actualizar su etapa, para que el sistema siga el proceso real y el resumen no tenga datos inventados.

**Criterios de aceptación**
- **Dado** que registro un cambio nuevo, **cuando** lo guardo, **entonces** queda en la etapa *Registrado* con resultado *Pendiente* y sin confirmación ni firmas.
- **Dado** un cambio *Registrado*, **cuando** indico la fecha de la sesión y si está firmado, **entonces** pasa a *Aprobado en sesión*.
- **Dado** un cambio *Aprobado en sesión*, **cuando** indico la fecha de ejecución, el resultado y la confirmación, **entonces** pasa a *Ejecutado*.
- **Dado** que el resultado es *Fallido* o *Revertido*, **cuando** guardo sin explicar qué pasó, **entonces** el sistema me lo pide.
- **Dado** una semana con cambios sin ejecutar, **cuando** gerencia intenta aprobarla, **entonces** el sistema lo impide e indica cuántos faltan.

**Estado:** corregido en la semana 5 (se cierra con el commit `Closes #N`).

---

## 2. [Grave] Buscar y filtrar en Cambios registrados

**Etiquetas:** `prueba-usuarios`, `grave`, `semana-6`
**Hallazgo:** H2 · frecuencia 1/1

**Problema**
Para encontrar un cambio hay que recorrer toda la tabla. Muchas personas se saben el código de su cambio y quieren buscarlo directamente.

**Historia**
Como usuario quiero buscar un cambio por su código, por área o por usuario, para encontrarlo sin revisar toda la lista.

**Criterios de aceptación**
- **Dado** que escribo un código de cambio (RFC, ID de solicitud o ID-RFC-BI), **cuando** busco, **entonces** veo solo los cambios que coinciden, aunque escriba solo una parte del código.
- **Dado** que elijo un área, **cuando** aplico el filtro, **entonces** veo solo los cambios de esa área.
- **Dado** que escribo un usuario, **cuando** aplico el filtro, **entonces** veo solo los cambios de ese usuario.
- **Dado** que combino filtros con la semana, **cuando** busco, **entonces** se aplican todos a la vez, y con **Limpiar filtros** vuelvo a ver todo.
- **Dado** que ningún cambio coincide, **cuando** busco, **entonces** veo el mensaje "No hay cambios que coincidan con la búsqueda".

**Estado:** corregido en la semana 6 (pull request `feature/busqueda-cambios`, se cierra con `Closes #N` en su descripción).

---

## 3. [Grave] Completar usuario y área a partir del código de empleado

**Etiquetas:** `prueba-usuarios`, `grave`, `semana-7`
**Hallazgo:** H3 · frecuencia 1/1

**Problema**
Al registrar un cambio hay que escribir el usuario y elegir el área a mano, aunque el empleado ya existe en la base. Es trabajo repetido y permite errores de escritura.

**Historia**
Como administrador de cambios quiero escribir el código de empleado y que se llenen solos su usuario y su área, para registrar más rápido y sin errores.

**Criterios de aceptación**
- **Dado** un código de empleado que existe, **cuando** lo escribo y salgo del campo, **entonces** se llenan el usuario y el área (y el ID de área).
- **Dado** un código que no existe, **cuando** salgo del campo, **entonces** veo el aviso "Empleado nuevo: completa usuario y área" y puedo llenarlos a mano.
- **Dado** que los datos se llenaron solos, **cuando** necesito corregirlos, **entonces** puedo editarlos antes de guardar.
- La consulta del empleado la resuelve una función del servidor que exige sesión iniciada; la tabla de empleados no se abre completa al navegador.
