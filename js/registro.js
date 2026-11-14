// Index.html · Registrar cambio (flujo central 1: llama a registrar_cambio en la base real)
(function () {
  "use strict";
  const { listar, rpc, hoy, mostrarMensaje } = window.CP;

  const form = document.getElementById("form-cambio");
  const msg = document.getElementById("mensaje");
  const boton = form.querySelector('button[type="submit"]');
  const el = form.elements;

  let areas = [];
  let clasificaciones = [];

  function llenar(select, filas, placeholder, nombreDefecto) {
    select.replaceChildren();
    if (placeholder) {
      const o = document.createElement("option");
      o.value = "";
      o.textContent = placeholder;
      select.append(o);
    }
    for (const f of filas) {
      const o = document.createElement("option");
      o.value = f.id;
      o.textContent = f.nombre;
      if (nombreDefecto && f.nombre === nombreDefecto) o.defaultSelected = true;
      select.append(o);
    }
  }

  function aplicarPorDefecto() {
    el.fechaIngreso.value = hoy();
    el.fechaIngreso.max = hoy();
    actualizarIdArea();
    actualizarRequisitoObservaciones();
  }

  function actualizarIdArea() {
    const a = areas.find((x) => String(x.id) === el.area.value);
    el.idArea.value = a ? a.codigo : "";
  }

  function actualizarRequisitoObservaciones() {
    const c = clasificaciones.find((x) => String(x.id) === el.clasificacion.value);
    const requerida = !!(c && c.requiere_justificacion);
    el.observaciones.required = requerida;
    el.observaciones.minLength = requerida ? 10 : 0;
    document.getElementById("ayuda-observaciones").hidden = !requerida;
  }

  async function cargarCatalogos() {
    mostrarMensaje(msg, "Cargando catálogos…", "info");
    try {
      const [a, c, r, am] = await Promise.all([
        listar("areas?select=id,codigo,nombre&activa=eq.true&order=nombre"),
        listar("clasificaciones?select=id,nombre,requiere_justificacion&order=id"),
        listar("resultados_cambio?select=id,nombre&order=id"),
        listar("ambitos_rfc?select=id,nombre&order=id")
      ]);
      areas = a;
      clasificaciones = c;
      llenar(el.area, a, "Selecciona un área…");
      llenar(el.clasificacion, c, "Selecciona una clasificación…");
      llenar(el.resultado, r, null, "Pendiente");
      llenar(el.rfcTipo, am);
      aplicarPorDefecto();
      msg.hidden = true;
      boton.disabled = false;
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
      boton.disabled = true;
    }
  }

  const numeroOnulo = (v) => (v ? Number(v) : null);

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    boton.disabled = true;
    mostrarMensaje(msg, "Guardando…", "info");
    try {
      const id = await rpc("registrar_cambio", {
        p_fecha_ingreso: el.fechaIngreso.value,
        p_codigo_empleado: el.codigoEmpleado.value,
        p_usuario: el.usuario.value,
        p_area_id: numeroOnulo(el.area.value),
        p_id_solicitud: el.idSolicitud.value,
        p_rfc: el.rfc.value,
        p_ambito_id: numeroOnulo(el.rfcTipo.value),
        p_id_rfc_bi: el.idRfcBi.value,
        p_actividad: el.actividad.value,
        p_clasificacion_id: numeroOnulo(el.clasificacion.value),
        p_resultado_id: numeroOnulo(el.resultado.value),
        p_confirmacion: el.confirmacion.value === "Sí",
        p_firmadas: el.firmadas.value === "Sí",
        p_observaciones: el.observaciones.value
      });
      form.reset();
      aplicarPorDefecto();
      mostrarMensaje(msg, "Cambio #" + id + " registrado correctamente.", "ok");
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    } finally {
      boton.disabled = false;
    }
  });

  el.area.addEventListener("change", actualizarIdArea);
  el.clasificacion.addEventListener("change", actualizarRequisitoObservaciones);

  boton.disabled = true;
  cargarCatalogos();
})();
