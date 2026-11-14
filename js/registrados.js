// CambiosRegistrados.html · lista de cambios leída desde la vista v_cambios_detalle
// Aprobador: solo lectura (por defecto ve la semana actual). Administrador: además edita y elimina.
// La base vuelve a comprobar el rol en v_cambios_detalle, actualizar_cambio y eliminar_cambio.
(function () {
  "use strict";
  const { listar, rpc, semanaActual, parseSemana, mostrarMensaje, ocultarMensaje, textoCelda, COLUMNAS_CAMBIOS } = window.CP;
  const LIMITE = 500;

  const cuerpo = document.querySelector("#cambios tbody");
  const msg = document.getElementById("mensaje");
  const inputSemana = document.getElementById("semana");
  let esAdmin = false;
  let catalogos = null;

  const totalColumnas = () => COLUMNAS_CAMBIOS.length + (esAdmin ? 1 : 0);

  function filaVacia(texto) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = totalColumnas();
    td.textContent = texto;
    tr.append(td);
    cuerpo.replaceChildren(tr);
  }

  function botonAccion(texto, clase, alHacerClic) {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "btn-mini " + clase;
    b.textContent = texto;
    b.addEventListener("click", alHacerClic);
    return b;
  }

  async function cargar() {
    mostrarMensaje(msg, "Cargando cambios…", "info");
    let ruta = "v_cambios_detalle?select=*&order=fecha_ingreso.desc,id.desc&limit=" + LIMITE;
    const s = parseSemana(inputSemana.value);
    if (s) ruta += "&semana_anio=eq." + s.anio + "&semana_num=eq." + s.semana;
    try {
      const filas = await listar(ruta);
      if (!filas.length) {
        filaVacia(s ? "No hay cambios registrados en esa semana." : "Aún no hay cambios registrados.");
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
        if (esAdmin) {
          const td = document.createElement("td");
          td.className = "acciones";
          if (fila.estado === "Aprobado") {
            td.textContent = "Aprobado: no editable";
          } else {
            td.append(
              botonAccion("Editar", "", () => abrirEditar(fila)),
              botonAccion("Eliminar", "btn-peligro", () => abrirEliminar(fila))
            );
          }
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

  // ---- Edición (Administrador) ----
  const dlgEditar = document.getElementById("dlg-editar");
  const fEditar = document.getElementById("form-editar");
  const msgEditar = document.getElementById("editar-mensaje");
  let cambioEnEdicion = null;

  async function cargarCatalogos() {
    if (catalogos) return catalogos;
    const [c, r] = await Promise.all([
      listar("clasificaciones?select=id,nombre,requiere_justificacion&order=id"),
      listar("resultados_cambio?select=id,nombre&order=id")
    ]);
    catalogos = { clasificaciones: c, resultados: r };
    const llenar = (select, filas) => select.replaceChildren(...filas.map((x) => new Option(x.nombre, x.id)));
    llenar(fEditar.elements.clasificacion, c);
    llenar(fEditar.elements.resultado, r);
    return catalogos;
  }

  async function abrirEditar(fila) {
    try {
      await cargarCatalogos();
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
      return;
    }
    cambioEnEdicion = fila;
    const e = fEditar.elements;
    document.getElementById("editar-resumen").textContent =
      "Cambio #" + fila.id + " · " + fila.fecha_ingreso + " · " + fila.usuario + " · " + fila.area;
    e.actividad.value = fila.actividad || "";
    e.clasificacion.value = String(fila.clasificacion_id);
    e.resultado.value = String(fila.resultado_id);
    e.confirmacion.value = fila.confirmacion ? "Sí" : "No";
    e.firmadas.value = fila.firmadas ? "Sí" : "No";
    e.observaciones.value = fila.observaciones || "";
    msgEditar.hidden = true;
    dlgEditar.showModal();
  }

  fEditar.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    if (!fEditar.reportValidity()) return;
    const e = fEditar.elements;
    const boton = fEditar.querySelector('button[type="submit"]');
    boton.disabled = true;
    try {
      await rpc("actualizar_cambio", {
        p_id: cambioEnEdicion.id,
        p_actividad: e.actividad.value,
        p_clasificacion_id: Number(e.clasificacion.value),
        p_resultado_id: Number(e.resultado.value),
        p_confirmacion: e.confirmacion.value === "Sí",
        p_firmadas: e.firmadas.value === "Sí",
        p_observaciones: e.observaciones.value
      });
      dlgEditar.close();
      await cargar();
      mostrarMensaje(msg, "Cambio #" + cambioEnEdicion.id + " actualizado.", "ok");
    } catch (err) {
      msgEditar.textContent = err.message;
      msgEditar.hidden = false;
    } finally {
      boton.disabled = false;
    }
  });

  // ---- Eliminación (Administrador) ----
  const dlgEliminar = document.getElementById("dlg-eliminar");
  const fEliminar = document.getElementById("form-eliminar");
  const msgEliminar = document.getElementById("eliminar-mensaje");
  let cambioAEliminar = null;

  function abrirEliminar(fila) {
    cambioAEliminar = fila;
    document.getElementById("eliminar-resumen").textContent =
      "¿Eliminar el cambio #" + fila.id + " (" + fila.fecha_ingreso + ", " + fila.usuario + ")? Se guardará una copia con el motivo.";
    fEliminar.reset();
    msgEliminar.hidden = true;
    dlgEliminar.showModal();
  }

  fEliminar.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    if (!fEliminar.reportValidity()) return;
    const boton = fEliminar.querySelector('button[type="submit"]');
    boton.disabled = true;
    try {
      await rpc("eliminar_cambio", { p_id: cambioAEliminar.id, p_motivo: fEliminar.elements.motivo.value });
      dlgEliminar.close();
      await cargar();
      mostrarMensaje(msg, "Cambio #" + cambioAEliminar.id + " eliminado.", "ok");
    } catch (err) {
      msgEliminar.textContent = err.message;
      msgEliminar.hidden = false;
    } finally {
      boton.disabled = false;
    }
  });

  for (const b of document.querySelectorAll("dialog .btn-cerrar")) {
    b.addEventListener("click", () => b.closest("dialog").close());
  }

  inputSemana.addEventListener("change", cargar);
  document.getElementById("btn-todas").addEventListener("click", () => { inputSemana.value = ""; cargar(); });

  window.AUTH.proteger(["Aprobador", "Administrador"]).then((perfil) => {
    if (!perfil) return;
    esAdmin = perfil.rol === "Administrador";
    for (const el of document.querySelectorAll(".solo-admin")) el.hidden = !esAdmin;
    inputSemana.value = semanaActual();
    cargar();
  });
})();
