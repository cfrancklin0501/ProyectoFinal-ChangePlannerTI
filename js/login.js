// login.html · iniciar sesión, crear cuenta y pedir el correo de recuperación
(function () {
  "use strict";
  const AUTH = window.AUTH;
  const msg = document.getElementById("mensaje");

  function mostrar(texto, tipo) {
    msg.textContent = texto;
    msg.className = "mensaje " + (tipo || "info");
    msg.hidden = false;
  }

  // A dónde volver después de entrar (solo páginas del propio sitio)
  function destino() {
    const v = new URLSearchParams(window.location.search).get("volver") || "";
    return /^[A-Za-z0-9_-]+\.html$/.test(v) && v !== "login.html" ? v : "index.html";
  }

  // ---- Pestañas ----
  const pestanas = [
    ["tab-entrar", "form-entrar"],
    ["tab-registro", "form-registro"],
    ["tab-recuperar", "form-recuperar"]
  ];
  function activar(idTab) {
    for (const [tab, form] of pestanas) {
      const activa = tab === idTab;
      document.getElementById(tab).setAttribute("aria-selected", String(activa));
      document.getElementById(form).hidden = !activa;
    }
    msg.hidden = true;
  }
  for (const [tab] of pestanas) {
    document.getElementById(tab).addEventListener("click", () => activar(tab));
  }

  async function conBoton(form, accion) {
    const boton = form.querySelector('button[type="submit"]');
    boton.disabled = true;
    try { await accion(); } catch (e) { mostrar(e.message, "error"); } finally { boton.disabled = false; }
  }

  // ---- Iniciar sesión ----
  const fEntrar = document.getElementById("form-entrar");
  fEntrar.addEventListener("submit", (ev) => {
    ev.preventDefault();
    conBoton(fEntrar, async () => {
      mostrar("Verificando…", "info");
      await AUTH.iniciarSesion(fEntrar.elements.correo.value, fEntrar.elements.contrasena.value);
      window.location.replace(destino());
    });
  });

  // ---- Crear cuenta ----
  const fRegistro = document.getElementById("form-registro");
  fRegistro.addEventListener("submit", (ev) => {
    ev.preventDefault();
    const e = fRegistro.elements;
    if (e.contrasena.value !== e.confirmar.value) {
      mostrar("Las contraseñas no coinciden.", "error");
      e.confirmar.focus();
      return;
    }
    if (!/[A-Za-z]/.test(e.contrasena.value) || !/\d/.test(e.contrasena.value)) {
      mostrar("La contraseña debe tener letras y números.", "error");
      e.contrasena.focus();
      return;
    }
    conBoton(fRegistro, async () => {
      mostrar("Creando tu cuenta…", "info");
      const r = await AUTH.registrarse(e.correo.value, e.contrasena.value, e.nombre.value);
      if (r.sesion) {
        window.location.replace("index.html");
        return;
      }
      fRegistro.reset();
      activar("tab-entrar");
      mostrar("Cuenta creada. Te enviamos un correo para confirmarla; después podrás iniciar sesión.", "ok");
    });
  });

  // ---- Recuperar contraseña ----
  const fRecuperar = document.getElementById("form-recuperar");
  fRecuperar.addEventListener("submit", (ev) => {
    ev.preventDefault();
    conBoton(fRecuperar, async () => {
      mostrar("Enviando…", "info");
      await AUTH.recuperarContrasena(fRecuperar.elements.correo.value);
      // Mismo mensaje exista o no la cuenta, para no revelar qué correos están registrados
      mostrar("Si el correo está registrado, recibirás un enlace para crear una contraseña nueva.", "ok");
    });
  });

  // ---- Al volver del correo de confirmación ----
  const r = AUTH.leerSesionDeUrl();
  if (r && r.error) {
    mostrar(r.error, "error");
  } else if (r && r.tipo === "recovery") {
    window.location.replace("restablecer.html");
  } else if (r && r.sesion) {
    window.location.replace("index.html");
  } else if (AUTH.leerSesion()) {
    // Ya hay sesión abierta
    window.location.replace(destino());
  }
})();
