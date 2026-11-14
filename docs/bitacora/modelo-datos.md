# Modelo de datos · ChangePlanner TI

Base de datos: **PostgreSQL en Supabase**. Las migraciones versionadas están en [`supabase/migrations/`](../supabase/migrations) y los datos de ejemplo en [`supabase/seed.sql`](../supabase/seed.sql).

El diagrama muestra el **producto completo (24 tablas)**. En la semana 3 se implementan las **12 tablas del núcleo** (con atributos); las otras 12 son el camino de las próximas semanas (solo identificador).

## Diagrama (producto completo)

```mermaid
erDiagram
  %% ---------- Implementadas en la semana 3 ----------
  AREAS {
    bigint id PK
    text codigo UK "ID Área"
    text nombre UK
    boolean activa
  }
  ROLES {
    bigint id PK
    text nombre UK
    text descripcion
  }
  EMPLEADOS {
    bigint id PK
    text codigo_empleado UK "opcional"
    text usuario UK "sin distinguir mayúsculas"
    text nombre_completo
    text correo
    bigint area_id FK
    bigint rol_id FK
    boolean activo
  }
  CLASIFICACIONES {
    bigint id PK
    text nombre UK
    boolean requiere_justificacion
  }
  AMBITOS_RFC {
    bigint id PK
    text nombre UK "Local o Regional"
  }
  RESULTADOS_CAMBIO {
    bigint id PK
    text nombre UK
    boolean es_final
  }
  SOLICITUDES {
    bigint id PK
    text codigo_solicitud UK "ID Solicitud"
  }
  RFCS {
    bigint id PK
    text codigo_rfc UK "RFC"
    bigint ambito_id FK
    text id_rfc_bi "ID-RFC-BI"
  }
  SEMANAS {
    bigint id PK
    smallint anio
    smallint semana
    date fecha_inicio
    date fecha_fin
    text estado "Abierta, Aprobada, Rechazada"
  }
  CAMBIOS {
    bigint id PK
    date fecha_ingreso
    bigint empleado_id FK
    bigint area_id FK "área al momento del cambio"
    bigint solicitud_id FK "opcional"
    bigint rfc_id FK "opcional"
    text actividad
    bigint clasificacion_id FK
    bigint resultado_id FK
    boolean confirmacion
    boolean firmadas
    text observaciones
    bigint semana_id FK
    text estado "Por aprobar, Aprobado, Rechazado"
  }
  APROBACIONES_SEMANALES {
    bigint id PK
    bigint semana_id FK
    text decision "Aprobada o Rechazada"
    text aprobado_por
    date fecha_aprobacion
    text comentarios
  }
  HISTORIAL_CAMBIOS {
    bigint id PK
    bigint cambio_id FK
    text accion "INSERT o UPDATE"
    jsonb datos_anteriores
    jsonb datos_nuevos
    timestamptz fecha
  }

  %% ---------- Próximas semanas ----------
  TIPOS_ACTIVO { bigint id PK }
  SITIOS { bigint id PK }
  ACTIVOS { bigint id PK }
  CAMBIO_ACTIVOS { bigint id PK }
  VENTANAS_MANTENIMIENTO { bigint id PK }
  PLANES_ROLLBACK { bigint id PK }
  ADJUNTOS { bigint id PK }
  FIRMAS { bigint id PK }
  COMENTARIOS { bigint id PK }
  NOTIFICACIONES { bigint id PK }
  ETIQUETAS { bigint id PK }
  CAMBIO_ETIQUETAS { bigint id PK }

  %% ---------- Relaciones del núcleo ----------
  AREAS ||--o{ EMPLEADOS : "agrupa"
  ROLES ||--o{ EMPLEADOS : "define el rol de"
  AREAS ||--o{ CAMBIOS : "área del cambio"
  EMPLEADOS ||--o{ CAMBIOS : "realiza"
  CLASIFICACIONES ||--o{ CAMBIOS : "clasifica"
  RESULTADOS_CAMBIO ||--o{ CAMBIOS : "resultado"
  SOLICITUDES |o--o{ CAMBIOS : "origina"
  AMBITOS_RFC ||--o{ RFCS : "ámbito"
  RFCS |o--o{ CAMBIOS : "respalda"
  SEMANAS ||--o{ CAMBIOS : "agrupa"
  SEMANAS ||--o{ APROBACIONES_SEMANALES : "se decide en"
  CAMBIOS ||--o{ HISTORIAL_CAMBIOS : "audita"

  %% ---------- Relaciones futuras ----------
  TIPOS_ACTIVO ||--o{ ACTIVOS : "tipifica"
  SITIOS ||--o{ ACTIVOS : "aloja"
  ACTIVOS ||--o{ CAMBIO_ACTIVOS : "es afectado en"
  CAMBIOS ||--o{ CAMBIO_ACTIVOS : "afecta"
  CAMBIOS ||--o{ VENTANAS_MANTENIMIENTO : "se programa en"
  CAMBIOS ||--o| PLANES_ROLLBACK : "tiene"
  CAMBIOS ||--o{ ADJUNTOS : "adjunta"
  CAMBIOS ||--o{ FIRMAS : "requiere"
  EMPLEADOS ||--o{ FIRMAS : "firma"
  CAMBIOS ||--o{ COMENTARIOS : "recibe"
  EMPLEADOS ||--o{ COMENTARIOS : "escribe"
  EMPLEADOS ||--o{ NOTIFICACIONES : "recibe"
  CAMBIOS ||--o{ CAMBIO_ETIQUETAS : "lleva"
  ETIQUETAS ||--o{ CAMBIO_ETIQUETAS : "se aplica en"
```

## Mapa de la tabla de Excel a la base

| Columna del Excel | Dónde vive ahora |
|---|---|
| Fecha de ingreso | `cambios.fecha_ingreso` |
| Código Empleado, Usuario | `empleados.codigo_empleado`, `empleados.usuario` |
| Área, ID Área | `areas.nombre`, `areas.codigo` (vía `cambios.area_id`) |
| ID Solicitud | `solicitudes.codigo_solicitud` |
| RFC, RFC Local/Regional, ID-RFC-BI | `rfcs.codigo_rfc`, `ambitos_rfc.nombre`, `rfcs.id_rfc_bi` |
| Actividad, Clasificación, Resultado | `cambios.actividad`, `clasificaciones`, `resultados_cambio` |
| Confirmación, Firmadas, Observaciones | `cambios.confirmacion`, `cambios.firmadas`, `cambios.observaciones` |
| Aprobado por, Fecha de Aprobación | `aprobaciones_semanales` (se muestran en la vista `v_cambios_detalle`) |
| Estado (columna nueva) | `cambios.estado` |

## Diccionario de datos (tablas implementadas)

Notación: **PK** llave primaria, **FK** llave foránea, **UK** única, **NN** no nula. Todas las llaves primarias son `bigint generated always as identity`.

### areas
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| codigo | text | UK | NN, no vacío (`areas_codigo_unico`) |
| nombre | text | UK | NN, no vacío (`areas_nombre_unico`) |
| activa | boolean | | NN, por defecto `true` |
| created_at | timestamptz | | NN, por defecto `now()` |

### roles
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| nombre | text | UK | NN (`roles_nombre_unico`). Valores: Solicitante, Ejecutor, Aprobador |
| descripcion | text | | |

### clasificaciones
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| nombre | text | UK | NN. Valores: Estándar, Normal, Emergencia |
| descripcion | text | | |
| requiere_justificacion | boolean | | NN, por defecto `false`. En Emergencia es `true` |

### ambitos_rfc
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| nombre | text | UK | NN. Valores: Local, Regional |

### resultados_cambio
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| nombre | text | UK | NN. Valores: Pendiente, Exitoso, Fallido, Revertido |
| es_final | boolean | | NN, por defecto `true` (Pendiente es `false`) |

### empleados
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| codigo_empleado | text | UK | Opcional (varios nulos permitidos) |
| usuario | text | UK | NN, no vacío; único sin distinguir mayúsculas (`empleados_usuario_unico` sobre `lower(usuario)`) |
| nombre_completo | text | | |
| correo | text | | Formato válido si se informa (`empleados_correo_formato`) |
| area_id | bigint | FK → areas.id | NN |
| rol_id | bigint | FK → roles.id | NN |
| activo | boolean | | NN, por defecto `true` |
| created_at, updated_at | timestamptz | | NN; `updated_at` lo mantiene un trigger |

### solicitudes
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| codigo_solicitud | text | UK | NN, no vacío |
| created_at | timestamptz | | NN |

### rfcs
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| codigo_rfc | text | UK | NN, no vacío |
| ambito_id | bigint | FK → ambitos_rfc.id | NN |
| id_rfc_bi | text | | |
| created_at | timestamptz | | NN |

### semanas
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| anio, semana | smallint | UK (anio, semana) | NN; `semana` entre 1 y 53; semana ISO (lunes a domingo) |
| fecha_inicio, fecha_fin | date | | NN; `fecha_fin = fecha_inicio + 6` |
| estado | text | | NN, por defecto `Abierta`; solo `Abierta`, `Aprobada` o `Rechazada` |
| created_at | timestamptz | | NN |

Se crea sola la primera vez que se registra un cambio de esa semana (`obtener_o_crear_semana`).

### cambios
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| fecha_ingreso | date | | NN; no puede ser futura (trigger) |
| empleado_id | bigint | FK → empleados.id | NN |
| area_id | bigint | FK → areas.id | NN. Guarda el área en el momento del cambio, aunque el empleado cambie de área después |
| solicitud_id | bigint | FK → solicitudes.id | Opcional |
| rfc_id | bigint | FK → rfcs.id | Opcional |
| actividad | text | | NN; mínimo 10 caracteres (`cambios_actividad_longitud`) |
| clasificacion_id | bigint | FK → clasificaciones.id | NN |
| resultado_id | bigint | FK → resultados_cambio.id | NN |
| confirmacion, firmadas | boolean | | NN, por defecto `false` |
| observaciones | text | | Obligatoria (mínimo 10 caracteres) si la clasificación requiere justificación |
| semana_id | bigint | FK → semanas.id | NN; la asigna un trigger a partir de `fecha_ingreso` |
| estado | text | | NN, por defecto `Por aprobar`; solo `Por aprobar`, `Aprobado` o `Rechazado` |
| created_at, updated_at | timestamptz | | NN |

### aprobaciones_semanales
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| semana_id | bigint | FK → semanas.id | NN |
| decision | text | | NN; solo `Aprobada` o `Rechazada` |
| aprobado_por | text | | NN; mínimo 3 caracteres |
| fecha_aprobacion | date | | NN; no puede ser futura (la valida la función) |
| comentarios | text | | Obligatorio (mínimo 5 caracteres) si la decisión es `Rechazada` (`aprobaciones_rechazo_con_comentario`) |
| created_at | timestamptz | | NN |

Una semana rechazada puede decidirse otra vez, por eso una semana puede tener varias filas; la vigente es la más reciente.

### historial_cambios
| Columna | Tipo | Llave | Restricciones |
|---|---|---|---|
| id | bigint | PK | |
| cambio_id | bigint | FK → cambios.id | NN |
| accion | text | | NN; `INSERT` o `UPDATE` |
| datos_anteriores | jsonb | | Solo en `UPDATE` |
| datos_nuevos | jsonb | | NN |
| ejecutado_por | text | | NN, por defecto el rol de base de datos que ejecutó el cambio |
| fecha | timestamptz | | NN |

Lo llena un trigger; la aplicación nunca escribe aquí.

## Qué pasa al borrar

| Si se borra… | …y existen | Comportamiento | Motivo |
|---|---|---|---|
| un área | empleados o cambios | **RESTRICT** (se bloquea) | Se desactiva (`activa = false`), no se borra |
| un rol | empleados | **RESTRICT** | Catálogo estable |
| una clasificación, resultado o ámbito | cambios o RFC | **RESTRICT** | Catálogos usados por el histórico |
| un empleado | cambios | **RESTRICT** | Se conserva quién hizo el cambio; se desactiva (`activo = false`) |
| una solicitud | cambios | **SET NULL** | El cambio sigue existiendo aunque se retire el ticket |
| un RFC | cambios | **SET NULL** | Igual que la solicitud |
| una semana | cambios | **RESTRICT** | Una semana con cambios no se puede borrar |
| una semana (sin cambios) | aprobaciones | **CASCADE** | Las decisiones no tienen sentido sin su semana |
| un cambio | historial | **CASCADE** | El borrado físico de un cambio es excepcional (solo administrador por SQL); la app nunca borra |

## Reglas de negocio que impone la base de datos

1. Actividad de al menos 10 caracteres.
2. La fecha de ingreso no puede ser futura.
3. Un cambio de **Emergencia** exige justificación en Observaciones (mínimo 10 caracteres).
4. Si se informa un RFC, hay que indicar si es Local o Regional.
5. Un usuario existe una sola vez (sin distinguir mayúsculas) y un código de empleado pertenece a un solo usuario.
6. Una **semana aprobada** queda cerrada: no admite cambios nuevos y sus cambios no se pueden modificar.
7. **Rechazar** una semana exige un comentario (mínimo 5 caracteres).
8. No se puede aprobar una semana sin cambios, ni una que ya fue aprobada.
9. Toda creación o modificación de un cambio queda en `historial_cambios`.

La aplicación muestra estos mensajes tal cual los devuelve la base (ver `js/api.js`).

## Acceso y seguridad

Todas las tablas tienen **RLS activado**. La web usa la clave pública (rol `anon`) y solo puede:

- **Leer** los catálogos y las vistas `v_cambios_detalle`, `v_resumen_semana` y `v_cambios_por_usuario` (no exponen el correo de los empleados).
- **Escribir** únicamente llamando a las funciones `registrar_cambio` y `aprobar_semana`. No hay `INSERT`, `UPDATE` ni `DELETE` directos.

**Limitación conocida:** todavía no hay inicio de sesión, así que cualquiera que conozca la URL puede ejecutar esas dos funciones. Se corregirá con Supabase Auth; mientras tanto no se deben cargar datos reales sensibles.
