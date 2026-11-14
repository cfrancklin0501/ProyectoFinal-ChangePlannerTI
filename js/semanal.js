// CambiosSemanal.html · resumen semanal, aprobación de gerencia (flujo central 2), CSV e impresión
(function () {
  "use strict";
  const CP = window.CP;
  const { listar, rpc, hoy, semanaActual, parseSemana, mostrarMensaje, ocultarMensaje, textoCelda } = CP;

  const inputSemana = document.getElementById("semana");
  const msg = document.getElementById("mensaje");
  const estadoSemana = document.getElementById("estado-semana");
  const cuerpoUsuarios = document.getElementById("cuerpo-usuarios");
  const form = document.getElementById("form-aprobacion");
  const btnRechazar = document.getElementById("btn-rechazar");

  const TOTALES = {
    total_cambios: "total-cambios",
    total_pendientes: "total-pendientes",
    total_aprobados: "total-aprobados",
    total_rechazados: "total-rechazados",
    total_sin_firmar: "total-sin-firmar"
  };

  const pad = (n) => String(n).padStart(2, "0");

  function pintarTotales(resumen) {
    for (const [campo, id] of Object.entries(TOTALES)) {
      document.getElementById(id).textContent = resumen ? resumen[campo] : 0;
    }
  }

  function pintarUsuarios(filas) {
    if (!filas.length) {
      cuerpoUsuarios.innerHTML = "";
      const tr = document.createElement("tr");
      const td = document.createElement("td");
      td.colSpan = 3;
      td.textContent = "Sin datos para esta semana.";
      tr.append(td);
      cuerpoUsuarios.append(tr);
      return;
    }
    const trs = filas.map((f) => {
      const tr = document.createElement("tr");
      for (const valor of [f.usuario, f.area, f.cambios]) {
        const td = document.createElement("td");
        td.textContent = valor;
        tr.append(td);
      }
      return tr;
    });
    cuerpoUsuarios.replaceChildren(...trs);
  }

  function pintarEstado(s, resumen) {
    let texto = "Semana " + s.anio + "-W" + pad(s.semana);
    if (!resumen) {
      texto += " · Sin cambios registrados.";
    } else {
      texto += " (" + resumen.fecha_inicio + " a " + resumen.fecha_fin + ") · Estado: " + resumen.estado_semana;
      if (resumen.aprobado_por) {
        texto += " · Última decisión de " + resumen.aprobado_por + " el " + resumen.fecha_aprobacion;
      }
    }
    estadoSemana.textContent = texto;
  }

  function habilitarAprobacion(resumen) {
    const puede = !!resumen && resumen.total_cambios > 0 && resumen.estado_semana !== "Aprobada";
    for (const control of form.elements) control.disabled = !puede;
  }

  async function cargar() {
    const s = parseSemana(inputSemana.value);
    if (!s) {
      pintarTotales(null);
      pintarUsuarios([]);
      estadoSemana.textContent = "Elige una semana.";
      habilitarAprobacion(null);
      return;
    }
    mostrarMensaje(msg, "Cargando resumen…", "info");
    try {
      const filtro = "anio=eq." + s.anio + "&semana=eq." + s.semana;
      const [resumenes, usuarios] = await Promise.all([
        listar("v_resumen_semana?select=*&" + filtro),
        listar("v_cambios_por_usuario?select=*&" + filtro + "&order=cambios.desc,usuario.asc")
      ]);
      const resumen = resumenes[0] || null;
      pintarTotales(resumen);
      pintarUsuarios(usuarios);
      pintarEstado(s, resumen);
      habilitarAprobacion(resumen);
      ocultarMensaje(msg);
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    }
  }

  async function decidir(decision) {
    const s = parseSemana(inputSemana.value);
    if (!s) { mostrarMensaje(msg, "Elige una semana.", "error"); return; }
    const comentarios = form.elements.comentarios;
    if (decision === "Rechazada" && comentarios.value.trim().length < 5) {
      mostrarMensaje(msg, "Para rechazar una semana escribe un comentario (mínimo 5 caracteres).", "error");
      comentarios.focus();
      return;
    }
    if (!form.reportValidity()) return;
    const pregunta = decision === "Aprobada"
      ? "¿Aprobar la semana " + s.anio + "-W" + pad(s.semana) + "? Después no se podrán registrar ni modificar cambios en ella."
      : "¿Rechazar la semana " + s.anio + "-W" + pad(s.semana) + "?";
    if (!window.confirm(pregunta)) return;

    mostrarMensaje(msg, "Guardando decisión…", "info");
    try {
      await rpc("aprobar_semana", {
        p_anio: s.anio,
        p_semana: s.semana,
        p_decision: decision,
        p_aprobado_por: form.elements.aprobadoPor.value,
        p_fecha_aprobacion: form.elements.fechaAprobacion.value,
        p_comentarios: comentarios.value
      });
      comentarios.value = "";
      await cargar();
      mostrarMensaje(msg, "Semana " + (decision === "Aprobada" ? "aprobada" : "rechazada") + " correctamente.", "ok");
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    }
  }

  // ---- CSV ----
  function celdaCsv(valor) {
    let t = String(valor === null || valor === undefined ? "" : valor);
    if (/^[=+\-@\t\r]/.test(t)) t = "'" + t; // evita fórmulas al abrir en Excel
    return '"' + t.replace(/"/g, '""') + '"';
  }

  async function exportarCsv() {
    const s = parseSemana(inputSemana.value);
    if (!s) { mostrarMensaje(msg, "Elige una semana.", "error"); return; }
    try {
      const filas = await listar(
        "v_cambios_detalle?select=*&semana_anio=eq." + s.anio + "&semana_num=eq." + s.semana + "&order=fecha_ingreso.asc,id.asc"
      );
      if (!filas.length) {
        mostrarMensaje(msg, "No hay cambios en esa semana para exportar.", "error");
        return;
      }
      const lineas = [CP.COLUMNAS_CAMBIOS.map((c) => celdaCsv(c.titulo)).join(CP.SEPARADOR_CSV)];
      for (const f of filas) {
        lineas.push(CP.COLUMNAS_CAMBIOS.map((c) => celdaCsv(textoCelda(c.campo, f[c.campo]))).join(CP.SEPARADOR_CSV));
      }
      const blob = new Blob(["\ufeff" + lineas.join("\r\n")], { type: "text/csv;charset=utf-8" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "cambios-" + s.anio + "-W" + pad(s.semana) + ".csv";
      document.body.append(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(a.href);
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    }
  }

  form.addEventListener("submit", (ev) => { ev.preventDefault(); decidir("Aprobada"); });
  btnRechazar.addEventListener("click", () => decidir("Rechazada"));
  document.getElementById("btn-csv").addEventListener("click", exportarCsv);
  document.getElementById("btn-imprimir").addEventListener("click", () => window.print());
  inputSemana.addEventListener("change", cargar);

  inputSemana.value = semanaActual();
  form.elements.fechaAprobacion.value = hoy();
  form.elements.fechaAprobacion.max = hoy();
  cargar();
})();
