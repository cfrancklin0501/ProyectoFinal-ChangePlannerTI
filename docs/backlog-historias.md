# Backlog · ChangePlannerTI

## Corte 1 · MVP (etiqueta `mvp`)

### H1 · Ver el formulario de registro
**Como** analista TI **quiero** abrir la página y ver el formulario de registro **para** empezar a documentar un cambio.
- **Dado** que abro la URL pública de la app, **cuando** carga la página, **entonces** veo el formulario con sus campos y el botón Guardar.
- **Dado** que la app está publicada, **cuando** la abro, **entonces** se sirve por HTTPS sin advertencias.

### H2 · Capturar los datos del cambio
**Como** analista TI **quiero** completar los datos del cambio **para** que quede el registro de lo que hice.
- **Dado** que estoy en el formulario, **cuando** completo Fecha de ingreso, Código Empleado, Usuario, Área, ID Solicitud, RFC, Actividad y Clasificación, **entonces** los valores quedan en los campos.
- **Dado** que el campo Clasificación tiene opciones, **cuando** lo despliego, **entonces** solo puedo elegir valores de la lista.

### H3 · Validar campos obligatorios
**Como** analista TI **quiero** que el formulario me avise si falta un dato clave **para** no guardar registros incompletos.
- **Dado** que dejo vacío Fecha, Usuario, RFC o Actividad, **cuando** presiono Guardar, **entonces** no se guarda y veo un mensaje junto al campo faltante.
- **Dado** que corrijo los campos señalados, **cuando** presiono Guardar de nuevo, **entonces** el mensaje desaparece y se guarda.

### H4 · Guardar el cambio
**Como** analista TI **quiero** guardar el registro **para** consultarlo después.
- **Dado** que el formulario está completo y válido, **cuando** presiono Guardar, **entonces** el cambio se almacena y veo una confirmación.
- **Dado** que guardé un cambio, **cuando** recargo la página, **entonces** el cambio sigue disponible.
- **Dado** que se guardó, **cuando** termina, **entonces** el formulario queda limpio para un nuevo registro.

### H5 · Ver la lista de cambios
**Como** analista TI **quiero** ver una tabla con los cambios registrados **para** revisar qué se ha hecho.
- **Dado** que existen cambios guardados, **cuando** abro la lista, **entonces** veo una fila por cambio con Fecha, Usuario, Área, RFC y Actividad.
- **Dado** que hay varios cambios, **cuando** se muestra la lista, **entonces** aparecen ordenados del más reciente al más antiguo.
- **Dado** que no hay cambios, **cuando** abro la lista, **entonces** veo el mensaje "Aún no hay cambios registrados".

### H6 · Ver el detalle de un cambio
**Como** analista TI **quiero** abrir un cambio y ver todos sus campos **para** revisar la información completa.
- **Dado** que estoy en la lista, **cuando** selecciono un cambio, **entonces** veo todos sus campos.
- **Dado** que estoy en el detalle, **cuando** presiono Volver, **entonces** regreso a la lista.

---
