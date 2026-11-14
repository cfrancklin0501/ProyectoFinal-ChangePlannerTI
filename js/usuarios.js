// Usuarios.html · gestión de usuarios y roles (solo Administrador)
// Crear: registro normal de Supabase Auth + admin_guardar_usuario para el rol.
// Leer: tabla perfiles (la política RLS deja ver todos solo al Administrador).
// Actualizar: admin_guardar_usuario. Eliminar: admin_eliminar_usuario.
(function () {
  "use strict";
  const { listar, rpc, mostrarMensaje, ocultarMensaje } = window.CP;
  const ROLES = ["Visualizador", "Aprobador", "Administrador"];

  const msg = document.getElementById("mensaje");
  const cuerpo = document.querySelector("#tabla-usuarios tbody");
  const fNuevo = document.getElementById("form-nuevo");
  let yo = null;

  function celda(contenido) {
    const td = document.createElement("td");
    if (contenido instanceof Node) td.append(contenido); else td.textContent = contenido;
    return td;
  }

  function filaUsuario(u) {
    const tr = document.createElement("tr");

    const nombre = document.createElement("input");
    nombre.type = "text";
    nombre.value = u.nombre_completo;
    nombre.minLength = 3;
    nombre.maxLength = 80;
    nombre.required = true;
    nombre.setAttribute("aria-label", "Nombre de " + u.correo);

    const rol = document.createElement("select");
    rol.setAttribute("aria-label", "Rol de " + u.correo);
    for (const r of ROLES) rol.append(new Option(r, r, false, r === u.rol));

    const activo = document.createElement("input");
    activo.type = "checkbox";
    activo.checked = u.activo;
    activo.setAttribute("aria-label", "Cuenta activa de " + u.correo);

    const esYo = u.id === yo.id;
    if (esYo) { rol.disabled = true; activo.disabled = true; }

    const guardar = document.createElement("button");
    guardar.type = "button";
    guardar.className = "btn-mini";
    guardar.textContent = "Guardar";
    guardar.addEventListener("click", async () => {
      if (!nombre.reportValidity()) return;
      guardar.disabled = true;
      try {
        await rpc("admin_guardar_usuario", { p_id: u.id, p_nombre: nombre.value, p_rol: rol.value, p_activo: activo.checked });
        mostrarMensaje(msg, "Usuario " + u.correo + " actualizado.", "ok");
        await cargar(false);
      } catch (e) {
        mostrarMensaje(msg, e.message, "error");
      } finally {
        guardar.disabled = false;
      }
    });

    const acciones = document.createElement("div");
    acciones.className = "acciones";
    acciones.append(guardar);
    if (!esYo) {
      const eliminar = document.createElement("button");
      eliminar.type = "button";
      eliminar.className = "btn-mini btn-peligro";
      eliminar.textContent = "Eliminar";
      eliminar.addEventListener("click", async () => {
        if (!window.confirm("¿Eliminar la cuenta de " + u.correo + "? Esta acción no se puede deshacer.")) return;
        eliminar.disabled = true;
        try {
          await rpc("admin_eliminar_usuario", { p_id: u.id });
          mostrarMensaje(msg, "Cuenta " + u.correo + " eliminada.", "ok");
          await cargar(false);
        } catch (e) {
          mostrarMensaje(msg, e.message, "error");
          eliminar.disabled = false;
        }
      });
      acciones.append(eliminar);
    } else {
      const nota = document.createElement("span");
      nota.className = "ayuda";
      nota.textContent = " (tu cuenta)";
      acciones.append(nota);
    }

    tr.append(
      celda(nombre), celda(u.correo), celda(rol), celda(activo),
      celda(new Date(u.created_at).toLocaleDateString("es")), celda(acciones)
    );
    return tr;
  }

  async function cargar(conAviso) {
    if (conAviso !== false) mostrarMensaje(msg, "Cargando usuarios…", "info");
    try {
      const usuarios = await listar("perfiles?select=id,correo,nombre_completo,rol,activo,created_at&order=nombre_completo");
      cuerpo.replaceChildren(...usuarios.map(filaUsuario));
      if (conAviso !== false) ocultarMensaje(msg);
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    }
  }

  fNuevo.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const e = fNuevo.elements;
    if (!/[A-Za-z]/.test(e.contrasena.value) || !/\d/.test(e.contrasena.value)) {
      mostrarMensaje(msg, "La contraseña temporal debe tener letras y números.", "error");
      return;
    }
    const boton = fNuevo.querySelector('button[type="submit"]');
    boton.disabled = true;
    mostrarMensaje(msg, "Creando usuario…", "info");
    try {
      // guardarSesion:false → el administrador sigue con su propia sesión
      const r = await window.AUTH.registrarse(e.correo.value, e.contrasena.value, e.nombre.value, { guardarSesion: false });
      let texto = "Usuario " + e.correo.value + " creado";
      if (r.usuarioId && e.rol.value !== "Visualizador") {
        await rpc("admin_guardar_usuario", { p_id: r.usuarioId, p_nombre: e.nombre.value, p_rol: e.rol.value, p_activo: true });
        texto += " con rol " + e.rol.value;
      }
      if (r.confirmar) texto += ". Debe confirmar su correo antes de entrar";
      fNuevo.reset();
      await cargar(false);
      mostrarMensaje(msg, texto + ".", "ok");
    } catch (err) {
      mostrarMensaje(msg, err.message, "error");
    } finally {
      boton.disabled = false;
    }
  });

  window.AUTH.proteger(["Administrador"]).then((perfil) => {
    if (!perfil) return;
    yo = perfil;
    cargar();
  });
})();
