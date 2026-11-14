-- ChangePlanner TI · Semana 3 · Datos semilla para DESARROLLO (nombres y correos ficticios)
-- Ejecutar DESPUÉS de las 5 migraciones. Es seguro repetirlo: si ya hay cambios, no vuelve a sembrar.

do $seed$
declare
  v_lunes date := current_date - (extract(isodow from current_date)::int - 1);  -- lunes de la semana actual
begin
  -- Empleados ficticios
  insert into empleados (codigo_empleado, usuario, nombre_completo, correo, area_id, rol_id)
  select v.cod, v.usr, v.nombre, v.correo, a.id, r.id
  from (values
    ('E1001', 'mrivera',    'María Rivera',     'mrivera@empresa.example',    'A01', 'Ejecutor'),
    ('E1002', 'jcastillo',  'José Castillo',    'jcastillo@empresa.example',  'A02', 'Ejecutor'),
    ('E1003', 'lmendoza',   'Lucía Mendoza',    'lmendoza@empresa.example',   'A03', 'Ejecutor'),
    ('E1004', 'pfuentes',   'Pedro Fuentes',    'pfuentes@empresa.example',   'A04', 'Ejecutor'),
    ('E1005', 'aalvarado',  'Ana Alvarado',     'aalvarado@empresa.example',  'A05', 'Ejecutor'),
    ('E1006', 'rguzman',    'Ricardo Guzmán',   'rguzman@empresa.example',    'A02', 'Ejecutor'),
    ('E1007', 'kpaz',       'Karla Paz',        'kpaz@empresa.example',       'A01', 'Ejecutor'),
    ('E1008', 'dhernandez', 'Daniel Hernández', 'dhernandez@empresa.example', 'A03', 'Ejecutor'),
    ('E9001', 'sflores',    'Sofía Flores',     'sflores@empresa.example',    'A03', 'Aprobador')
  ) as v(cod, usr, nombre, correo, area, rol)
  join areas a on a.codigo = v.area
  join roles r on r.nombre = v.rol
  on conflict do nothing;

  if exists (select 1 from cambios) then
    raise notice 'Ya hay cambios registrados: no se siembran datos de ejemplo.';
    return;
  end if;

  create temp table tmp_seed (
    semana_atras int, dia int, usuario text, solicitud text, rfc text, ambito text, bi text,
    actividad text, clasif text, resultado text, conf boolean, firm boolean, obs text
  );

  insert into tmp_seed values
    -- Hace dos semanas (se aprueba al final)
    (2,0,'mrivera',   'SOL-2026-1101','RFC-L-0412','Local',   'BI-7731','Reemplazo de switch de acceso en piso 3 por equipo defectuoso','Normal','Exitoso',true,true,null),
    (2,1,'jcastillo', 'SOL-2026-1104','RFC-R-0088','Regional','BI-7740','Actualización de reglas del firewall perimetral Palo Alto para nuevo segmento de proveedores','Normal','Exitoso',true,true,'Validado con el área de seguridad regional'),
    (2,1,'lmendoza',  'SOL-2026-1105','RFC-L-0415','Local',   'BI-7742','Parcheo mensual de servidores Windows del ambiente de desarrollo','Estándar','Exitoso',true,true,null),
    (2,2,'pfuentes',  'SOL-2026-1108','RFC-L-0418','Local',   'BI-7750','Ampliación de espacio en tablespace de la base de datos de facturación','Normal','Exitoso',true,true,null),
    (2,3,'aalvarado', null,           null,        null,      null,     'Configuración de VPN para equipo de usuario remoto de contabilidad','Estándar','Exitoso',true,false,'Falta la firma del formato por parte del usuario'),
    (2,4,'rguzman',   'SOL-2026-1112','RFC-L-0421','Local',   'BI-7761','Corrección urgente de regla de acceso que bloqueaba el sistema de nómina','Emergencia','Exitoso',true,true,'Bloqueo detectado en cierre de quincena; se aplicó el cambio de inmediato y se documentó después'),
    -- La semana pasada (queda por aprobar)
    (1,0,'kpaz',      'SOL-2026-1120','RFC-L-0430','Local',   'BI-7788','Cambio de enlace secundario de internet a nuevo proveedor','Normal','Exitoso',true,true,null),
    (1,1,'dhernandez','SOL-2026-1123','RFC-R-0092','Regional','BI-7795','Migración de máquina virtual del ERP a nuevo clúster de virtualización','Normal','Revertido',true,true,'Se revirtió por latencia alta en el almacenamiento; se reprogramará'),
    (1,2,'jcastillo', 'SOL-2026-1126','RFC-R-0095','Regional','BI-7801','Actualización de PAN-OS en el firewall perimetral','Normal','Exitoso',true,false,'Pendiente la firma del acta de cambio'),
    (1,2,'mrivera',   'SOL-2026-1127','RFC-L-0434','Local',   'BI-7803','Reemplazo de fuente de poder redundante en switch de core','Estándar','Exitoso',true,true,null),
    (1,3,'lmendoza',  'SOL-2026-1130','RFC-L-0436','Local',   'BI-7810','Reinicio programado de servidores de aplicaciones tras actualizar librerías','Estándar','Exitoso',true,true,null),
    (1,4,'pfuentes',  'SOL-2026-1133','RFC-L-0439','Local',   'BI-7815','Respaldo y restauración de prueba de la base de datos de inventario','Estándar','Fallido',false,false,'La restauración falló por falta de espacio en el destino; se repetirá'),
    (1,4,'aalvarado', null,           null,        null,      null,     'Reinstalación de impresoras de red en el área administrativa','Estándar','Exitoso',true,true,null),
    -- Esta semana
    (0,0,'rguzman',   'SOL-2026-1140','RFC-L-0442','Local',   'BI-7822','Creación de reglas de acceso para el nuevo sistema de gestión documental','Normal','Pendiente',false,false,null),
    (0,1,'kpaz',      'SOL-2026-1143','RFC-L-0445','Local',   'BI-7829','Configuración de VLAN para la nueva oficina de ventas','Normal','Exitoso',true,true,null),
    (0,2,'dhernandez','SOL-2026-1146','RFC-L-0448','Local',   'BI-7833','Aumento de memoria RAM en el servidor de archivos','Estándar','Exitoso',true,false,null),
    (0,3,'mrivera',   'SOL-2026-1149','RFC-R-0099','Regional','BI-7840','Cambio de firmware en equipos de red del centro de datos','Normal','Pendiente',false,false,null);

  insert into solicitudes (codigo_solicitud)
  select distinct solicitud from tmp_seed where solicitud is not null
  on conflict do nothing;

  insert into rfcs (codigo_rfc, ambito_id, id_rfc_bi)
  select distinct on (t.rfc) t.rfc, am.id, t.bi
  from tmp_seed t join ambitos_rfc am on am.nombre = t.ambito
  where t.rfc is not null
  on conflict do nothing;

  insert into cambios (fecha_ingreso, empleado_id, area_id, solicitud_id, rfc_id, actividad,
                       clasificacion_id, resultado_id, confirmacion, firmadas, observaciones)
  select least(v_lunes - 7 * t.semana_atras + t.dia, current_date),
         e.id, e.area_id, sol.id, r.id, t.actividad, cl.id, rc.id, t.conf, t.firm, t.obs
  from tmp_seed t
  join empleados e          on lower(e.usuario) = t.usuario
  join clasificaciones cl   on cl.nombre = t.clasif
  join resultados_cambio rc on rc.nombre = t.resultado
  left join solicitudes sol on sol.codigo_solicitud = t.solicitud
  left join rfcs r          on r.codigo_rfc = t.rfc
  order by t.semana_atras desc, t.dia;

  drop table tmp_seed;

  -- La semana de hace dos semanas ya fue aprobada por gerencia
  perform aprobar_semana(
    extract(isoyear from v_lunes - 14)::int,
    extract(week from v_lunes - 14)::int,
    'Aprobada', 'Sofía Flores', v_lunes - 14 + 4,
    'Semana revisada; cambios conformes.'
  );
end $seed$;
