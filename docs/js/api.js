// Cliente mínimo para la API REST de Supabase (PostgREST), sin librerías externas.
// Expone window.CP con utilidades compartidas por las tres páginas.
(function () {
  "use strict";

  const SEPARADOR_CSV = ","; // si tu Excel abre el CSV en una sola columna, cámbialo a ";"

  const MENSAJES_RESTRICCION = {
    empleados_usuario_unico: "Ya existe un empleado con ese usuario.",
    empleados_codigo_unico: "Ya existe un empleado con ese código.",
    empleados_correo_formato: "El correo no tiene un formato válido.",
    cambios_actividad_longitud: "La actividad debe tener al menos 10 caracteres."
  };

  const COLUMNAS_CAMBIOS = [
    { campo: "fecha_ingreso", titulo: "Fecha de ingreso" },
    { campo: "codigo_empleado", titulo: "Código Empleado" },
    { campo: "usuario", titulo: "Usuario" },
    { campo: "area", titulo: "Área" },
    { campo: "id_area", titulo: "ID Área" },
    { campo: "id_solicitud", titulo: "ID Solicitud" },
    { campo: "rfc", titulo: "RFC" },
    { campo: "rfc_ambito", titulo: "RFC Local / Regional" },
    { campo: "id_rfc_bi", titulo: "ID-RFC-BI" },
    { campo: "actividad", titulo: "Actividad" },
    { campo: "clasificacion", titulo: "Clasificación" },
    { campo: "resultado", titulo: "Resultado" },
    { campo: "confirmacion", titulo: "Confirmación" },
    { campo: "aprobado_por", titulo: "Aprobado por" },
    { campo: "fecha_aprobacion", titulo: "Fecha de Aprobación" },
    { campo: "firmadas", titulo: "Firmadas" },
    { campo: "observaciones", titulo: "Observaciones" },
    { campo: "estado", titulo: "Estado" }
  ];

  function configuracion() {
    const c = window.CONFIG || {};
    if (!c.SUPABASE_URL || c.SUPABASE_URL.includes("TU-PROYECTO") ||
        !c.SUPABASE_ANON_KEY || c.SUPABASE_ANON_KEY.includes("TU-CLAVE")) {
      throw new Error("Falta configurar js/config.js con la URL y la clave pública de Supabase.");
    }
    return c;
  }

  function cabeceras(clave) {
    const h = { apikey: clave, "Content-Type": "application/json" };
    // Las claves antiguas (anon) son JWT y también van en Authorization; las nuevas (publishable) no.
    if (clave.startsWith("eyJ")) h.Authorization = "Bearer " + clave;
    return h;
  }

  function traducirError(datos, estado) {
    console.error("Error de la API:", estado, datos);
    if (!datos || typeof datos !== "object") {
      return "El servidor respondió con un error (" + estado + ").";
    }
    if (datos.code === "P0001" && datos.message) return datos.message; // reglas de negocio de la base
    const texto = datos.message || "";
    for (const [nombre, mensaje] of Object.entries(MENSAJES_RESTRICCION)) {
      if (texto.includes(nombre)) return mensaje;
    }
    if (datos.code === "23503") return "No se puede completar: el registro está relacionado con otros datos.";
    if (datos.code === "42501") return "No tienes permiso para realizar esta acción.";
    if (datos.code === "PGRST202" || datos.code === "PGRST205" || datos.code === "42P01") {
      return "La base de datos no tiene el esquema esperado. ¿Ya se ejecutaron las migraciones?";
    }
    return "No se pudo completar la operación. Intenta de nuevo o avisa al administrador.";
  }

  async function pedir(ruta, opciones) {
    const c = configuracion();
    let resp;
    try {
      resp = await fetch(c.SUPABASE_URL + "/rest/v1/" + ruta, Object.assign({}, opciones, {
        headers: cabeceras(c.SUPABASE_ANON_KEY)
      }));
    } catch (e) {
      throw new Error("No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.");
    }
    const texto = await resp.text();
    let datos = null;
    try { datos = texto ? JSON.parse(texto) : null; } catch (e) { datos = null; }
    if (!resp.ok) throw new Error(traducirError(datos, resp.status));
    return datos;
  }

  const listar = (ruta) => pedir(ruta, { method: "GET" });
  const rpc = (nombre, argumentos) =>
    pedir("rpc/" + nombre, { method: "POST", body: JSON.stringify(argumentos) });

  // ---- Fechas (siempre en hora LOCAL del usuario, nunca UTC) ----
  const dos = (n) => String(n).padStart(2, "0");
  const hoy = () => {
    const d = new Date();
    return d.getFullYear() + "-" + dos(d.getMonth() + 1) + "-" + dos(d.getDate());
  };

  function semanaIso(fecha) {
    const d = new Date(Date.UTC(fecha.getFullYear(), fecha.getMonth(), fecha.getDate()));
    const dia = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - dia);
    const inicioAnio = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
    return { anio: d.getUTCFullYear(), semana: Math.ceil(((d - inicioAnio) / 86400000 + 1) / 7) };
  }
  const valorSemana = (s) => s.anio + "-W" + dos(s.semana);
  const semanaActual = () => valorSemana(semanaIso(new Date()));
  function parseSemana(valor) {
    const m = /^(\d{4})-W(\d{2})$/.exec(valor || "");
    return m ? { anio: Number(m[1]), semana: Number(m[2]) } : null;
  }

  // ---- Interfaz ----
  function mostrarMensaje(elemento, texto, tipo) {
    elemento.textContent = texto;
    elemento.className = "mensaje " + (tipo || "info");
    elemento.hidden = false;
  }
  function ocultarMensaje(elemento) {
    elemento.textContent = "";
    elemento.hidden = true;
  }
  function textoCelda(campo, valor) {
    if (valor === null || valor === undefined) return "";
    if (typeof valor === "boolean") return valor ? "Sí" : "No";
    return String(valor);
  }

  window.CP = {
    SEPARADOR_CSV, COLUMNAS_CAMBIOS,
    listar, rpc, hoy, semanaActual, valorSemana, parseSemana,
    mostrarMensaje, ocultarMensaje, textoCelda
  };
})();
