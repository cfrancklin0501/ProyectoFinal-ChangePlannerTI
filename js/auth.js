// Inicio de sesión con Supabase Auth (API REST, sin librerías externas).
// Expone window.AUTH: sesión, registro, recuperación de contraseña, protección de páginas y menú por rol.
//
// IMPORTANTE: ocultar menús o páginas en el navegador es solo comodidad.
// La seguridad real está en la base de datos (supabase/migrations/...0006_autenticacion_roles.sql):
// cada vista y cada función comprueba el rol del usuario que hace la petición.
(function () {
  "use strict";

  const CLAVE_SESION = "cp_sesion";

  // Páginas del menú y roles que las ven
  const MENU = [
    { href: "index.html",              texto: "Inicio",             roles: ["Visualizador", "Aprobador", "Administrador"] },
    { href: "RegistrarCambio.html",    texto: "Registrar cambio",   roles: ["Administrador"] },
    { href: "CambiosRegistrados.html", texto: "Cambios registrados", roles: ["Aprobador", "Administrador"] },
    { href: "CambiosSemanal.html",     texto: "Resumen semanal",    roles: ["Visualizador", "Aprobador", "Administrador"] },
    { href: "Usuarios.html",           texto: "Usuarios",           roles: ["Administrador"] }
  ];

  const MENSAJES_AUTH = {
    invalid_credentials: "Correo o contraseña incorrectos.",
    email_not_confirmed: "Todavía no confirmas tu correo. Revisa tu bandeja de entrada (y la de spam).",
    user_already_exists: "Ya existe una cuenta con ese correo. Inicia sesión o recupera tu contraseña.",
    email_exists: "Ya existe una cuenta con ese correo. Inicia sesión o recupera tu contraseña.",
    weak_password: "La contraseña es muy débil. Usa al menos 8 caracteres, con letras y números.",
    same_password: "La nueva contraseña debe ser distinta de la anterior.",
    over_email_send_rate_limit: "Se enviaron demasiados correos. Espera unos minutos e intenta de nuevo.",
    over_request_rate_limit: "Demasiados intentos. Espera unos minutos e intenta de nuevo.",
    email_address_invalid: "El correo no es válido.",
    validation_failed: "Revisa los datos: el correo o la contraseña no son válidos.",
    signup_disabled: "El registro de cuentas nuevas está desactivado.",
    user_banned: "Tu cuenta está bloqueada. Contacta al administrador."
  };

  // ---- Almacenamiento (localStorage puede no estar disponible) ----
  let enMemoria = null;
  function leerSesion() {
    try {
      const t = window.localStorage.getItem(CLAVE_SESION);
      return t ? JSON.parse(t) : null;
    } catch (e) {
      return enMemoria;
    }
  }
  function guardarSesion(s) {
    enMemoria = s;
    try {
      if (s) window.localStorage.setItem(CLAVE_SESION, JSON.stringify(s));
      else window.localStorage.removeItem(CLAVE_SESION);
    } catch (e) { /* sin almacenamiento: queda en memoria */ }
  }

  function config() {
    const c = window.CONFIG || {};
    if (!c.SUPABASE_URL || !c.SUPABASE_ANON_KEY) {
      throw new Error("Falta configurar js/config.js con la URL y la clave pública de Supabase.");
    }
    return c;
  }

  // Lee el contenido (payload) de un JWT sin validarlo: solo para saber el id del usuario
  function contenidoJwt(token) {
    try {
      const parte = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      const json = decodeURIComponent(atob(parte).split("").map(
        (c) => "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2)).join(""));
      return JSON.parse(json);
    } catch (e) {
      return {};
    }
  }

  function sesionDesdeRespuesta(d) {
    const ahora = Math.floor(Date.now() / 1000);
    const expira = Number(d.expires_at) || ahora + (Number(d.expires_in) || 3600);
    const jwt = contenidoJwt(d.access_token);
    return {
      access_token: d.access_token,
      refresh_token: d.refresh_token,
      expires_at: expira,
      user_id: (d.user && d.user.id) || jwt.sub,
      email: (d.user && d.user.email) || jwt.email || ""
    };
  }

  function traducirErrorAuth(d, estado) {
    console.error("Error de autenticación:", estado, d);
    if (d && typeof d === "object") {
      const codigo = d.error_code || d.code || d.error;
      if (codigo && MENSAJES_AUTH[codigo]) return MENSAJES_AUTH[codigo];
      const texto = String(d.msg || d.message || d.error_description || "");
      if (/invalid login credentials/i.test(texto)) return MENSAJES_AUTH.invalid_credentials;
      if (/email not confirmed/i.test(texto)) return MENSAJES_AUTH.email_not_confirmed;
      if (/already registered/i.test(texto)) return MENSAJES_AUTH.user_already_exists;
      if (/password should be at least/i.test(texto)) return "La contraseña debe tener al menos 8 caracteres.";
      if (/rate limit/i.test(texto)) return MENSAJES_AUTH.over_request_rate_limit;
    }
    if (estado === 429) return MENSAJES_AUTH.over_request_rate_limit;
    return "No se pudo completar la operación (" + estado + "). Intenta de nuevo.";
  }

  async function pedirAuth(ruta, opciones, token) {
    const c = config();
    const headers = { apikey: c.SUPABASE_ANON_KEY, "Content-Type": "application/json" };
    if (token) headers.Authorization = "Bearer " + token;
    let resp;
    try {
      resp = await fetch(c.SUPABASE_URL + "/auth/v1/" + ruta, Object.assign({}, opciones, { headers }));
    } catch (e) {
      throw new Error("No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.");
    }
    const texto = await resp.text();
    let datos = null;
    try { datos = texto ? JSON.parse(texto) : null; } catch (e) { datos = null; }
    if (!resp.ok) throw new Error(traducirErrorAuth(datos, resp.status));
    return datos;
  }

  // URL absoluta de otra página del sitio (para los enlaces de los correos)
  function urlPagina(pagina) {
    return new URL(pagina, window.location.href).href.split("#")[0].split("?")[0];
  }

  // ---- Acciones de autenticación ----
  async function iniciarSesion(correo, contrasena) {
    const d = await pedirAuth("token?grant_type=password", {
      method: "POST",
      body: JSON.stringify({ email: correo.trim(), password: contrasena })
    });
    const s = sesionDesdeRespuesta(d);
    guardarSesion(s);
    return s;
  }

  // Devuelve { sesion } si el proyecto no pide confirmar el correo, o { confirmar: true } si se envió un correo.
  async function registrarse(correo, contrasena, nombre, opciones) {
    const guardar = !opciones || opciones.guardarSesion !== false;
    const d = await pedirAuth("signup?redirect_to=" + encodeURIComponent(urlPagina("login.html")), {
      method: "POST",
      body: JSON.stringify({ email: correo.trim(), password: contrasena, data: { nombre_completo: nombre.trim() } })
    });
    if (d && d.access_token) {
      const s = sesionDesdeRespuesta(d);
      if (guardar) guardarSesion(s);
      return { sesion: s, usuarioId: s.user_id };
    }
    const usuario = (d && d.user) || d || {};
    return { confirmar: true, usuarioId: usuario.id || null };
  }

  async function recuperarContrasena(correo) {
    await pedirAuth("recover?redirect_to=" + encodeURIComponent(urlPagina("restablecer.html")), {
      method: "POST",
      body: JSON.stringify({ email: correo.trim() })
    });
  }

  async function cambiarContrasena(contrasena) {
    const token = await obtenerToken();
    if (!token) throw new Error("El enlace expiró. Solicita uno nuevo desde «¿Olvidaste tu contraseña?».");
    await pedirAuth("user", { method: "PUT", body: JSON.stringify({ password: contrasena }) }, token);
  }

  async function cerrarSesion() {
    const s = leerSesion();
    guardarSesion(null);
    if (s && s.access_token) {
      try { await pedirAuth("logout", { method: "POST" }, s.access_token); } catch (e) { /* ya no importa */ }
    }
    window.location.replace("login.html");
  }

  // Renueva el token cuando le queda menos de un minuto (una sola renovación a la vez)
  let renovando = null;
  async function obtenerToken() {
    const s = leerSesion();
    if (!s || !s.access_token) return null;
    const ahora = Math.floor(Date.now() / 1000);
    if (s.expires_at - ahora > 60) return s.access_token;
    if (!s.refresh_token) { guardarSesion(null); return null; }
    if (!renovando) {
      renovando = pedirAuth("token?grant_type=refresh_token", {
        method: "POST",
        body: JSON.stringify({ refresh_token: s.refresh_token })
      }).then((d) => {
        const nueva = sesionDesdeRespuesta(d);
        guardarSesion(nueva);
        return nueva.access_token;
      }).catch(() => {
        guardarSesion(null);
        return null;
      }).finally(() => { renovando = null; });
    }
    return renovando;
  }

  // Los enlaces de los correos (confirmación y recuperación) vuelven con la sesión en el #hash
  function leerSesionDeUrl() {
    const hash = window.location.hash.replace(/^#/, "");
    if (!hash) return null;
    const p = new URLSearchParams(hash);
    if (p.get("error") || p.get("error_description")) {
      history.replaceState(null, "", window.location.pathname + window.location.search);
      const codigo = p.get("error_code");
      if (codigo === "otp_expired") return { error: "El enlace del correo expiró o ya se usó. Solicita uno nuevo." };
      return { error: "El enlace del correo no es válido: " + (p.get("error_description") || "").replace(/\+/g, " ") };
    }
    if (!p.get("access_token")) return null;
    const s = sesionDesdeRespuesta({
      access_token: p.get("access_token"),
      refresh_token: p.get("refresh_token"),
      expires_at: p.get("expires_at"),
      expires_in: p.get("expires_in")
    });
    guardarSesion(s);
    history.replaceState(null, "", window.location.pathname + window.location.search);
    return { sesion: s, tipo: p.get("type") };
  }

  // ---- Perfil y protección de páginas ----
  async function cargarPerfil(s) {
    const c = config();
    const token = await obtenerToken();
    if (!token) return null;
    const resp = await fetch(
      c.SUPABASE_URL + "/rest/v1/perfiles?select=id,correo,nombre_completo,rol,activo&id=eq." + encodeURIComponent(s.user_id),
      { headers: { apikey: c.SUPABASE_ANON_KEY, Authorization: "Bearer " + token } }
    );
    if (resp.status === 401) { guardarSesion(null); return null; }
    if (!resp.ok) throw new Error("No se pudo cargar tu perfil (" + resp.status + "). ¿Ya se ejecutó la migración 6?");
    const filas = await resp.json();
    return filas[0] || null;
  }

  function irAlLogin() {
    const pagina = window.location.pathname.split("/").pop() || "index.html";
    window.location.replace("login.html?volver=" + encodeURIComponent(pagina));
  }

  function pintarMenu(perfil) {
    const nav = document.querySelector("header nav");
    const actual = (window.location.pathname.split("/").pop() || "index.html").toLowerCase();
    if (nav) {
      nav.replaceChildren();
      for (const item of MENU) {
        if (!item.roles.includes(perfil.rol)) continue;
        const a = document.createElement("a");
        a.href = item.href;
        a.textContent = item.texto;
        if (item.href.toLowerCase() === actual) a.setAttribute("aria-current", "page");
        nav.append(a);
      }
    }
    const header = document.querySelector("header");
    if (header && !document.getElementById("sesion")) {
      const caja = document.createElement("div");
      caja.id = "sesion";
      caja.className = "sesion";
      const quien = document.createElement("span");
      quien.textContent = perfil.nombre_completo + " · ";
      const rol = document.createElement("strong");
      rol.className = "rol";
      rol.textContent = perfil.rol;
      quien.append(rol);
      const salir = document.createElement("button");
      salir.type = "button";
      salir.className = "btn-salir";
      salir.textContent = "Cerrar sesión";
      salir.addEventListener("click", cerrarSesion);
      caja.append(quien, salir);
      header.prepend(caja);
    }
  }

  function mostrarSinPermiso(texto) {
    const main = document.querySelector("main");
    const seccion = document.createElement("section");
    const h2 = document.createElement("h2");
    h2.textContent = "Sin permiso";
    const p = document.createElement("p");
    p.textContent = texto;
    const a = document.createElement("a");
    a.href = "index.html";
    a.textContent = "Volver al inicio";
    seccion.append(h2, p, a);
    main.replaceChildren(seccion);
    main.hidden = false;
  }

  // Cada página la llama al empezar. Devuelve el perfil si el usuario puede ver la página; si no, null.
  async function proteger(rolesPermitidos) {
    const desdeUrl = leerSesionDeUrl();
    const s = (desdeUrl && desdeUrl.sesion) || leerSesion();
    if (!s) { irAlLogin(); return null; }
    let perfil;
    try {
      perfil = await cargarPerfil(s);
    } catch (e) {
      mostrarSinPermiso(e.message);
      return null;
    }
    if (!perfil) { irAlLogin(); return null; }
    if (!perfil.activo) {
      guardarSesion(null);
      mostrarSinPermiso("Tu cuenta está desactivada. Contacta al administrador.");
      return null;
    }
    pintarMenu(perfil);
    if (rolesPermitidos && !rolesPermitidos.includes(perfil.rol)) {
      mostrarSinPermiso("Tu rol (" + perfil.rol + ") no tiene acceso a esta página.");
      return null;
    }
    const main = document.querySelector("main");
    if (main) main.hidden = false;
    return perfil;
  }

  window.AUTH = {
    MENU,
    leerSesion, obtenerToken, contenidoJwt, leerSesionDeUrl, cargarPerfil,
    iniciarSesion, registrarse, recuperarContrasena, cambiarContrasena, cerrarSesion,
    proteger, irAlLogin
  };
})();
