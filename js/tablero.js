// index.html · Bienvenida: tablero gerencial (indicadores, gráfico por área y tabla dinámica)
// Lee la vista v_tablero (conteos agregados). La ven los tres roles.
(function () {
  "use strict";
  const { listar, hoy, mostrarMensaje, ocultarMensaje } = window.CP;

  // Orden fijo y color por resultado (colores de estado: siempre con leyenda y etiqueta, nunca solos)
  const RESULTADOS = [
    { nombre: "Exitoso",   color: "#0CA30C" },
    { nombre: "Fallido",   color: "#D03B3B" },
    { nombre: "Revertido", color: "#EC835A" },
    { nombre: "Pendiente", color: "#A8A79E" }
  ];
  const ORDEN_COLUMNAS = {
    resultado: RESULTADOS.map((r) => r.nombre),
    clasificacion: ["Estándar", "Normal", "Emergencia"],
    estado: ["Por aprobar", "Aprobado", "Rechazado"]
  };
  const FINALES = ["Exitoso", "Fallido", "Revertido"];

  const f = document.getElementById("filtros").elements;
  const msg = document.getElementById("mensaje");
  const grafico = document.getElementById("grafico");
  const tooltip = document.getElementById("tooltip");
  const selColumnas = document.getElementById("pivote-columnas");

  let filas = [];   // filas de v_tablero ya filtradas por fecha
  const nf = new Intl.NumberFormat("es");
  const pct = (a, b) => (b ? (Math.round((a / b) * 1000) / 10).toLocaleString("es") + " %" : "–");

  // ---- Períodos rápidos ----
  function periodo(tipo) {
    const h = hoy();
    f.hasta.value = h;
    if (tipo === "mes") f.desde.value = h.slice(0, 8) + "01";
    else if (tipo === "anio") f.desde.value = h.slice(0, 5) + "01-01";
    else f.desde.value = "2000-01-01";
  }

  // ---- Datos ----
  async function cargar() {
    if (!f.desde.value || !f.hasta.value) return;
    if (f.desde.value > f.hasta.value) {
      mostrarMensaje(msg, "La fecha «Desde» no puede ser posterior a «Hasta».", "error");
      return;
    }
    mostrarMensaje(msg, "Cargando tablero…", "info");
    try {
      filas = await listar(
        "v_tablero?select=*&fecha_ingreso=gte." + f.desde.value + "&fecha_ingreso=lte." + f.hasta.value
      );
      llenarAreas();
      pintar();
      if (!filas.length) mostrarMensaje(msg, "No hay cambios registrados en ese período.", "info");
      else ocultarMensaje(msg);
    } catch (e) {
      mostrarMensaje(msg, e.message, "error");
    }
  }

  function llenarAreas() {
    const elegida = f.area.value;
    const areas = [...new Set(filas.map((x) => x.area))].sort((a, b) => a.localeCompare(b, "es"));
    f.area.replaceChildren(new Option("Todas las áreas", ""));
    for (const a of areas) f.area.append(new Option(a, a));
    f.area.value = areas.includes(elegida) ? elegida : "";
  }

  const visibles = () => (f.area.value ? filas.filter((x) => x.area === f.area.value) : filas);

  function sumar(lista, condicion) {
    return lista.reduce((t, x) => t + (condicion(x) ? x.cambios : 0), 0);
  }

  // ---- Indicadores ----
  function pintarKpis(lista) {
    const total = sumar(lista, () => true);
    const ejecutado = sumar(lista, (x) => FINALES.includes(x.resultado));
    const exitos = sumar(lista, (x) => x.resultado === "Exitoso");
    const fallos = sumar(lista, (x) => x.resultado === "Fallido");
    document.getElementById("kpi-total").textContent = nf.format(total);
    document.getElementById("kpi-ejecutado").textContent = nf.format(ejecutado);
    document.getElementById("kpi-exito").textContent = pct(exitos, ejecutado);
    document.getElementById("kpi-exito-det").textContent = ejecutado ? nf.format(exitos) + " de " + nf.format(ejecutado) + " ejecutados" : "Sin cambios ejecutados";
    document.getElementById("kpi-fallo").textContent = pct(fallos, ejecutado);
    document.getElementById("kpi-fallo-det").textContent = ejecutado ? nf.format(fallos) + " de " + nf.format(ejecutado) + " ejecutados" : "Sin cambios ejecutados";
    document.getElementById("kpi-pendiente").textContent = nf.format(total - ejecutado);
  }

  // ---- Gráfico de barras apiladas por área ----
  function pintarLeyenda() {
    const leyenda = document.getElementById("leyenda");
    leyenda.replaceChildren(...RESULTADOS.map((r) => {
      const s = document.createElement("span");
      const m = document.createElement("i");
      m.style.background = r.color;
      s.append(m, document.createTextNode(r.nombre));
      return s;
    }));
  }

  function pintarGrafico(lista) {
    const porArea = new Map();
    for (const x of lista) {
      if (!porArea.has(x.area)) porArea.set(x.area, { total: 0 });
      const a = porArea.get(x.area);
      a.total += x.cambios;
      a[x.resultado] = (a[x.resultado] || 0) + x.cambios;
    }
    const areas = [...porArea.entries()].sort((a, b) => b[1].total - a[1].total || a[0].localeCompare(b[0], "es"));
    if (!areas.length) {
      const p = document.createElement("p");
      p.className = "ayuda";
      p.textContent = "Sin datos para mostrar.";
      grafico.replaceChildren(p);
      return;
    }
    const maximo = areas[0][1].total;
    grafico.replaceChildren(...areas.map(([area, datos]) => {
      const fila = document.createElement("div");
      fila.className = "barra-fila";
      const etiqueta = document.createElement("span");
      etiqueta.className = "barra-etiqueta";
      etiqueta.textContent = area;
      const pista = document.createElement("div");
      pista.className = "barra-pista";
      const barra = document.createElement("div");
      barra.className = "barra";
      barra.style.width = (datos.total / maximo) * 100 + "%";
      for (const r of RESULTADOS) {
        const n = datos[r.nombre] || 0;
        if (!n) continue;
        const seg = document.createElement("div");
        seg.className = "segmento";
        seg.style.flexGrow = n;
        seg.style.background = r.color;
        seg.dataset.texto = area + " · " + r.nombre + ": " + nf.format(n) + " (" + pct(n, datos.total) + ")";
        barra.append(seg);
      }
      const total = document.createElement("span");
      total.className = "barra-total";
      total.textContent = nf.format(datos.total);
      pista.append(barra, total);
      fila.append(etiqueta, pista);
      return fila;
    }));
  }

  // Tooltip por segmento (zona de contacto: toda la altura de la fila)
  grafico.addEventListener("mousemove", (ev) => {
    const seg = ev.target.closest(".segmento");
    if (!seg) { tooltip.hidden = true; return; }
    tooltip.textContent = seg.dataset.texto;
    tooltip.hidden = false;
    const caja = grafico.getBoundingClientRect();
    tooltip.style.left = Math.min(ev.clientX - caja.left + 12, caja.width - tooltip.offsetWidth) + "px";
    tooltip.style.top = ev.clientY - caja.top + grafico.offsetTop - 36 + "px";
  });
  grafico.addEventListener("mouseleave", () => { tooltip.hidden = true; });

  // ---- Tabla dinámica: filas = área, columnas = resultado / clasificación / estado ----
  function pintarPivote(lista) {
    const campo = selColumnas.value;
    const presentes = new Set(lista.map((x) => x[campo]));
    const columnas = ORDEN_COLUMNAS[campo].filter((c) => presentes.has(c))
      .concat([...presentes].filter((c) => !ORDEN_COLUMNAS[campo].includes(c)).sort());
    const conExito = campo === "resultado";

    const cabecera = ["Área", ...columnas, "Total"].concat(conExito ? ["Tasa de éxito"] : []);
    const trh = document.createElement("tr");
    for (const t of cabecera) {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = t;
      trh.append(th);
    }
    const tabla = document.getElementById("pivote");
    tabla.tHead.replaceChildren(trh);

    const matriz = new Map();
    for (const x of lista) {
      if (!matriz.has(x.area)) matriz.set(x.area, {});
      const m = matriz.get(x.area);
      m[x[campo]] = (m[x[campo]] || 0) + x.cambios;
    }
    const areas = [...matriz.keys()].sort((a, b) => a.localeCompare(b, "es"));
    const cuerpo = tabla.tBodies[0];
    if (!areas.length) {
      const tr = document.createElement("tr");
      const td = document.createElement("td");
      td.colSpan = cabecera.length;
      td.textContent = "Sin datos para el período elegido.";
      tr.append(td);
      cuerpo.replaceChildren(tr);
      return;
    }

    function fila(nombre, valores, esTotal) {
      const tr = document.createElement("tr");
      if (esTotal) tr.className = "fila-total";
      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = nombre;
      tr.append(th);
      let total = 0;
      for (const c of columnas) {
        const n = valores[c] || 0;
        total += n;
        const td = document.createElement("td");
        td.className = "num";
        td.textContent = n ? nf.format(n) : "–";
        tr.append(td);
      }
      const tdT = document.createElement("td");
      tdT.className = "num";
      tdT.textContent = nf.format(total);
      tr.append(tdT);
      if (conExito) {
        const ejec = FINALES.reduce((t, c) => t + (valores[c] || 0), 0);
        const td = document.createElement("td");
        td.className = "num";
        td.textContent = pct(valores.Exitoso || 0, ejec);
        tr.append(td);
      }
      return tr;
    }

    const totales = {};
    for (const m of matriz.values()) for (const [k, v] of Object.entries(m)) totales[k] = (totales[k] || 0) + v;
    cuerpo.replaceChildren(...areas.map((a) => fila(a, matriz.get(a), false)), fila("Total", totales, true));
  }

  function pintar() {
    const lista = visibles();
    pintarKpis(lista);
    pintarGrafico(lista);
    pintarPivote(lista);
  }

  // ---- Eventos ----
  f.desde.addEventListener("change", cargar);
  f.hasta.addEventListener("change", cargar);
  f.area.addEventListener("change", pintar);
  selColumnas.addEventListener("change", () => pintarPivote(visibles()));
  for (const b of document.querySelectorAll("[data-periodo]")) {
    b.addEventListener("click", () => { periodo(b.dataset.periodo); cargar(); });
  }

  window.AUTH.proteger(null).then((perfil) => {
    if (!perfil) return;
    document.getElementById("saludo").textContent = "Bienvenido, " + perfil.nombre_completo;
    pintarLeyenda();
    periodo("anio");
    cargar();
  });
})();
