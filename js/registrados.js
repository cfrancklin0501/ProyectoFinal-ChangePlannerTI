// CambiosRegistrados.html · lista de cambios leída desde la vista v_cambios_detalle
(function () {
  "use strict";
  const { listar, mostrarMensaje, ocultarMensaje, textoCelda, COLUMNAS_CAMBIOS } = window.CP;
  const LIMITE = 500;

  const cuerpo = document.querySelector("#cambios tbody");
  const msg = document.getElementById("mensaje");

  function filaVacia(texto) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = COLUMNAS_CAMBIOS.length;
    td.textContent = texto;
    tr.append(td);
    cuerpo.replaceChildren(tr);
  }

  async function cargar() {
    mostrarMensaje(msg, "Cargando cambios…", "info");
    try {
      const filas = await listar(
        "v_cambios_detalle?select=*&order=fecha_ingreso.desc,id.desc&limit=" + LIMITE
      );
      if (!filas.length) {
        filaVacia("Aún no hay cambios registrados.");
        ocultarMensaje(msg);
        return;
      }
      const trs = filas.map((fila) => {
        const tr = document.createElement("tr");
        for (const col of COLUMNAS_CAMBIOS) {
          const td = document.createElement("td");
          td.textContent = textoCelda(col.campo, fila[col.campo]); // textContent: evita inyección de HTML
          tr.append(td);
        }
        return tr;
      });
      cuerpo.replaceChildren(...trs);
      if (filas.length === LIMITE) {
        mostrarMensaje(msg, "Mostrando los " + LIMITE + " cambios más recientes.", "info");
      } else {
        ocultarMensaje(msg);
      }
    } catch (e) {
      filaVacia("No se pudieron cargar los cambios.");
      mostrarMensaje(msg, e.message, "error");
    }
  }

  cargar();
})();