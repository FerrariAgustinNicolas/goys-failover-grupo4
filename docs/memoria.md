# Memoria del Laboratorio — Failover Routing

**Grupo:** 4  
**Materia:** Gestión Operativa y Seguridad en Redes (GOYS)
**Fecha de entrega:** viernes 23/10/2026

## Integrantes y roles

| Integrante | Rol |
| --- | --- |
| FerrariAgustinNicolas | R1 — Líder / Edge-WAN |
| Valentinosiadore | R2 — Proveedores |
| AgusKlos | R3 — Core |
| naimguar | R4 — Distribución |
| LoLoo03 | R5 — Hosts / QA / Operación |

---

## 1. Diseño (F0)

### 1.1 Corrección del diagrama

La consigna identifica cinco problemas en el diseño original. Cada integrante documentará las correcciones correspondientes a su área.

| # | Defecto detectado | Corrección aplicada | Justificación |
| :-: | --- | --- | --- |
| 1 | Firewall sin par de alta disponibilidad, generando un punto único de falla (SPOF). | Recomendación para producción: utilizar un par de firewalls en alta disponibilidad/failover. No se aplica en este laboratorio, que conserva un solo EDGE. | Un único firewall puede interrumpir la conectividad entre la red interna e Internet ante una falla del dispositivo. Un par redundante permite mantener el servicio si uno de los equipos queda fuera de operación. |
| 2 | iBGP Route Reflector mal ubicado en el diseño original. | Se utiliza eBGP directamente entre EDGE (AS 65000) e ISP-1 (AS 65001) / ISP-2 (AS 65002), sin Route Reflector. | Los proveedores pertenecen a sistemas autónomos diferentes, por lo que corresponde utilizar eBGP. En esta topología no existe necesidad de incorporar un Route Reflector iBGP. |
| 3 | HSRP en el core (diseño *collapsed*): el gateway redundante de las LAN vive en el core, que además hace de tránsito. | El primer salto redundante se mueve a distribución con VRRP: DIST-1 es master del grupo 10 (USERS) y DIST-2 del grupo 20 (SERVERS). El core queda como tránsito puro, solo con OSPF. | Cada capa cumple una función: el core solo reenvía y no concentra servicios de LAN. La falla de un gateway afecta a una sola LAN y no al core. VRRP es un estándar abierto (RFC 5798), mientras que HSRP es propietario de Cisco. Con dos grupos se reparte la carga entre DIST-1 y DIST-2. |
| 4 | Sin enlace core–core: CORE-1 y CORE-2 no están conectados directamente, por lo que solo se comunican a través de EDGE o de una DIST. | Se agrega el enlace CORE-1 ↔ CORE-2 (`10.255.0.16/30`, CORE-1 `.17` / CORE-2 `.18`) en el área 0 de OSPF, con autenticación MD5. | Si un CORE pierde su enlace hacia EDGE, sin el enlace core–core su tráfico tendría que bajar a una DIST y volver a subir por el otro CORE, convirtiendo a la distribución en tránsito. Con el enlace directo, OSPF reconverge por el core y la distribución mantiene su función. Además, la adyacencia core–core forma parte de los requisitos de OSPF del laboratorio. |

### 1.2 Plan de direccionamiento (IPAM)

Para evitar solapamientos y simplificar la administración de la red, se propone separar el direccionamiento según su función.

#### Criterio de direccionamiento

| Uso | Bloque reservado | Criterio |
| --- | --- | --- |
| Enlaces punto a punto | `10.255.0.0/24` | División en subredes `/30` consecutivas |
| Loopbacks / Router-ID | `10.255.255.0/24` | Una dirección `/32` por router |
| LAN USERS | `192.168.10.0/24` | Red de usuarios con gateway virtual VRRP |
| LAN SERVERS | `192.168.20.0/24` | Red de servidores con gateway virtual VRRP |

Los enlaces punto a punto utilizan subredes `/30` independientes. Cada una dispone de dos direcciones utilizables y pertenece exclusivamente a un enlace, evitando solapamientos.

#### Enlaces y LAN

| Enlace / Red | Subred | Dispositivo A (IP/iface) | Dispositivo B (IP/iface) |
| --- | --- | --- | --- |
| ISP-1 ↔ EDGE | `10.255.0.0/30` | ISP-1: `10.255.0.1` / interfaz pendiente | EDGE: `10.255.0.2` / interfaz pendiente |
| ISP-2 ↔ EDGE | `10.255.0.4/30` | ISP-2: `10.255.0.5` / interfaz pendiente | EDGE: `10.255.0.6` / interfaz pendiente |
| EDGE ↔ CORE-1 | `10.255.0.8/30` | EDGE: `10.255.0.9` / interfaz pendiente | CORE-1: `10.255.0.10` / interfaz pendiente |
| EDGE ↔ CORE-2 | `10.255.0.12/30` | EDGE: `10.255.0.13` / interfaz pendiente | CORE-2: `10.255.0.14` / interfaz pendiente |
| CORE-1 ↔ CORE-2 | `10.255.0.16/30` | CORE-1: `10.255.0.17` / interfaz pendiente | CORE-2: `10.255.0.18` / interfaz pendiente |
| CORE-1 ↔ DIST-1 | `10.255.0.20/30` | CORE-1: `10.255.0.21` / interfaz pendiente | DIST-1: `10.255.0.22` / interfaz pendiente |
| CORE-1 ↔ DIST-2 | `10.255.0.24/30` | CORE-1: `10.255.0.25` / interfaz pendiente | DIST-2: `10.255.0.26` / interfaz pendiente |
| CORE-2 ↔ DIST-1 | `10.255.0.28/30` | CORE-2: `10.255.0.29` / interfaz pendiente | DIST-1: `10.255.0.30` / interfaz pendiente |
| CORE-2 ↔ DIST-2 | `10.255.0.32/30` | CORE-2: `10.255.0.33` / interfaz pendiente | DIST-2: `10.255.0.34` / interfaz pendiente |
| USERS | `192.168.10.0/24` | DIST-1: `192.168.10.2` / DIST-2: `192.168.10.3` (interfaz pendiente) | Gateway VRRP: `192.168.10.1` · PC-USER: `192.168.10.100` |
| SERVERS | `192.168.20.0/24` | DIST-1: `192.168.20.2` / DIST-2: `192.168.20.3` (interfaz pendiente) | Gateway VRRP: `192.168.20.1` · SRV: `192.168.20.100` |

> **Aporte R4 — enlaces CORE ↔ DIST:** se continúa la numeración consecutiva de `/30` a partir del bloque que sigue a EDGE. Queda reservado `10.255.0.16/30` para CORE-1 ↔ CORE-2 (a confirmar por R3). Convención: el CORE toma la primera IP utilizable y el DIST la segunda de cada `/30`. Las direcciones del lado CORE son una propuesta de R4, sujeta a la confirmación de R3.
>
> **Direccionamiento de las LAN:** en cada LAN, `.1` es la IP virtual VRRP (gateway de los hosts), `.2` es DIST-1, `.3` es DIST-2 y `.100` es el host.

> **Aporte R3 — enlace CORE ↔ CORE:** se utiliza el bloque reservado `10.255.0.16/30` para CORE-1 ↔ CORE-2, con CORE-1 en `.17` y CORE-2 en `.18`, siguiendo la convención de que el dispositivo con menor numeración toma la primera IP utilizable. Se confirman las direcciones del lado CORE propuestas por R4 en los enlaces CORE ↔ DIST.

> Los nombres de las interfaces se completarán a partir del proyecto GNS3 `topologia_failover_routing`. Los números de interfaz observados en el diagrama de ejemplo no se consideran vinculantes para el diseño del grupo.

#### VRRP

La consigna establece dos grupos VRRP con balanceo de carga: DIST-1 será master del grupo 10 y DIST-2 será master del grupo 20. Cada DIST es master de un grupo y backup del otro, de modo que ambos routers cursan tráfico en operación normal (load-sharing).

| Grupo | VRID | IP virtual | Master | Priority master | Backup | Priority backup |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| USERS | 10 | `192.168.10.1` | DIST-1 (`192.168.10.2`) | 150 | DIST-2 (`192.168.10.3`) | 100 |
| SERVERS | 20 | `192.168.20.1` | DIST-2 (`192.168.20.3`) | 150 | DIST-1 (`192.168.20.2`) | 100 |

Parámetros comunes a ambos grupos:

| Parámetro | Valor | Justificación |
| --- | --- | --- |
| Preempt | Habilitado | El master original recupera el rol al volver de una falla, restableciendo el reparto de carga. |
| Intervalo de anuncios | 1 s | Valor por defecto; la falla del master se detecta en unos 3 s. |
| Versión | VRRPv2 | Es la versión que admite autenticación. |
| Autenticación | Ver sección 1.3 | Evita que un dispositivo no autorizado se declare master. |

#### Loopbacks / Router-IDs

Se reserva el bloque `10.255.255.0/24` para las direcciones de loopback y Router-ID, utilizando una dirección `/32` por router.

Como criterio general se propone una numeración consecutiva por dispositivo.

| Nodo | Loopback / Router-ID |
| --- | --- |
| ISP-1 | `10.255.255.1/32` |
| ISP-2 | `10.255.255.2/32` |
| EDGE | `10.255.255.3/32` |
| CORE-1 | `10.255.255.4/32` |
| CORE-2 | `10.255.255.5/32` |
| DIST-1 | `10.255.255.6/32` |
| DIST-2 | `10.255.255.7/32` |

Numeración propuesta, consecutiva y en el orden de las capas: ISP-1 `.1`, ISP-2 `.2`, EDGE `.3`, CORE-1 `.4`, CORE-2 `.5`, DIST-1 `.6`, DIST-2 `.7`. Los DIST usan su loopback como router-id de OSPF.

> **Aporte R2 — loopbacks de ISP:** ISP-1 e ISP-2 usan su loopback como router-id de BGP. Además, esa dirección es el destino que simula "Internet": en F3, la salida a Internet se considera verificada cuando un host de USERS o SERVERS alcanza `10.255.255.1` (vía ISP-1) o `10.255.255.2` (vía ISP-2).

CORE-1 (`10.255.255.4/32`) y CORE-2 (`10.255.255.5/32`) también usan su loopback como router-id de OSPF, de modo que el identificador no dependa del estado de ninguna interfaz física (aporte R3).

La asignación de EDGE forma parte del diseño de R1. Las restantes direcciones serán completadas por los responsables correspondientes manteniendo el bloque reservado y verificando que no existan duplicaciones.

#### Sesiones eBGP

> **Aporte R2 — Proveedores:** revisión de las dos sesiones eBGP entre EDGE y los proveedores.

| Sesión | Extremo EDGE | Extremo ISP | Subred | Autenticación | Anuncio del ISP hacia EDGE |
| --- | --- | --- | --- | --- | --- |
| EDGE ↔ ISP-1 | `10.255.0.2` · AS 65000 · RID `10.255.255.3` | `10.255.0.1` · AS 65001 · RID `10.255.255.1` | `10.255.0.0/30` | TCP-MD5 `G4-BGP-ISP1-26` | `default-originate` (`0.0.0.0/0`) |
| EDGE ↔ ISP-2 | `10.255.0.6` · AS 65000 · RID `10.255.255.3` | `10.255.0.5` · AS 65002 · RID `10.255.255.2` | `10.255.0.4/30` | TCP-MD5 `G4-BGP-ISP2-26` | `default-originate` (`0.0.0.0/0`) |

- Las sesiones se establecen entre las IP de los enlaces `/30` (eBGP directo, sin multihop), no entre loopbacks: si el enlace cae, la sesión cae con él.
- Cada sesión usa su propia clave TCP-MD5, con el mismo valor en ambos extremos.
- Cada ISP anuncia una ruta por defecto hacia EDGE (`default-originate`). Con las dos sesiones activas, EDGE recibe dos defaults; si un proveedor cae, su ruta se retira y queda la del otro. Esa es la base del failover de salida a Internet.
- Verificación de consistencia (F0): las IP de peering pertenecen a sus `/30`, los AS coinciden con los de la corrección del diagrama (defecto 2) y la topología, y los router-id no se repiten.

### 1.3 Política de seguridad

#### Claves de autenticación

Las claves utilizadas serán exclusivas del entorno de laboratorio y no corresponderán a contraseñas personales ni a credenciales reutilizadas en otros servicios.

| Mecanismo | Enlace / grupo | Clave de laboratorio | Responsable |
| --- | --- | --- | --- |
| BGP TCP-MD5 | EDGE ↔ ISP-1 | `G4-BGP-ISP1-26` | R1 / R2 |
| BGP TCP-MD5 | EDGE ↔ ISP-2 | `G4-BGP-ISP2-26` | R1 / R2 |
| OSPF MD5 | Área 0 | `G4-OSPF-26` | R3 |
| VRRP | USERS — VRID 10 | `G4VRP-10` | R4 |
| VRRP | SERVERS — VRID 20 | `G4VRP-20` | R4 |

Las claves BGP se mantienen separadas para cada proveedor, de modo que una misma credencial no sea compartida por ambas sesiones eBGP.

La clave OSPF es única para toda el área 0: todas las interfaces que forman adyacencias (EDGE, CORE y DIST) deben usar el mismo valor y el mismo identificador de clave.

Las claves VRRP son independientes para cada grupo y tienen 8 caracteres, el máximo del campo de autenticación de VRRPv2.

#### Aporte R1 — EDGE/WAN

**Usuarios y privilegios**

En EDGE se utilizarán cuentas diferenciadas según su función:

- `admin`: cuenta administrativa destinada a tareas de configuración.
- `monitor`: cuenta con privilegios de solo lectura destinada a monitoreo y verificación.

No se utilizarán cuentas compartidas con credenciales personales de los integrantes.

**Servicios de administración**

Se mantendrán habilitados únicamente los servicios necesarios para la administración del laboratorio.

En EDGE se deshabilitarán los servicios que no sean requeridos, incluyendo:

- Telnet
- FTP
- HTTP
- API

Los servicios de administración que permanezcan habilitados, como SSH o Winbox, deberán restringirse al plano de gestión y no quedar expuestos innecesariamente hacia los enlaces de proveedores.

**Autenticación BGP**

Las dos sesiones eBGP:

- EDGE ↔ ISP-1
- EDGE ↔ ISP-2

utilizarán autenticación TCP-MD5.

Se utilizará una clave independiente para cada proveedor:

- EDGE ↔ ISP-1: `G4-BGP-ISP1-26`
- EDGE ↔ ISP-2: `G4-BGP-ISP2-26`

Las claves son exclusivas del entorno de laboratorio y no corresponden a credenciales personales ni reutilizadas en otros servicios. R1 y R2 deberán utilizar los mismos valores en ambos extremos de cada sesión BGP.

**Firewall EDGE**

El firewall de EDGE seguirá una política restrictiva:

1. permitir tráfico necesario para el funcionamiento de la red;
2. permitir las sesiones BGP con ISP-1 e ISP-2;
3. permitir únicamente el tráfico de administración autorizado;
4. permitir tráfico perteneciente a conexiones establecidas o relacionadas;
5. descartar tráfico de entrada no solicitado o no autorizado;
6. registrar eventos relevantes cuando sea necesario para verificación y troubleshooting.

Las reglas concretas se implementarán en F3, luego de la aprobación del diseño F0.

#### Aporte R2 — Proveedores

**Usuarios y privilegios**

En ISP-1 e ISP-2 se aplica el mismo esquema que en EDGE y DIST: `admin` para configuración y `monitor` con permisos de solo lectura. No se usan credenciales personales.

**Servicios de administración**

Se deshabilitan Telnet, FTP, HTTP y API. Se mantiene únicamente SSH.

**Autenticación BGP**

Cada ISP autentica su sesión eBGP con EDGE mediante TCP-MD5, con el mismo valor que EDGE en su extremo:

- ISP-1 ↔ EDGE: `G4-BGP-ISP1-26`
- ISP-2 ↔ EDGE: `G4-BGP-ISP2-26`

Una sesión con clave distinta o sin clave no se establece. Esto evita que un equipo no autorizado forme una sesión BGP con EDGE o inyecte rutas en ella.

#### Aporte R4 — Distribución

**Usuarios y privilegios**

En DIST-1 y DIST-2 se aplica el mismo esquema que en EDGE: `admin` para configuración y `monitor` con permisos de solo lectura. No se usan credenciales personales.

**Servicios de administración**

Se deshabilitan Telnet, FTP, HTTP y API. Se mantiene únicamente SSH, y en las interfaces hacia las LAN USERS/SERVERS no se atienden servicios de administración.

**Autenticación VRRP**

Los dos grupos usan VRRPv2 con autenticación `simple` y una clave independiente por grupo:

- USERS (VRID 10): `G4VRP-10`
- SERVERS (VRID 20): `G4VRP-20`

La autenticación `simple` viaja en texto claro dentro del segmento, por lo que protege contra equipos mal configurados y no contra un atacante con acceso al enlace. Se documenta como limitación en la sección 5. DIST-1 y DIST-2 deben configurar el mismo valor en cada grupo.

**Plano de control en DIST**

- Las interfaces hacia las LAN se declaran pasivas en OSPF, de modo que no se formen adyacencias con hosts.
- Las interfaces hacia CORE usan la autenticación OSPF MD5 definida por R3.

#### Aporte R3 — Core

**Usuarios y privilegios**

En CORE-1 y CORE-2 se aplica el mismo esquema que en EDGE y DIST: `admin` para configuración y `monitor` con permisos de solo lectura. No se usan credenciales personales.

**Servicios de administración**

Se deshabilitan Telnet, FTP, HTTP y API. Se mantiene únicamente SSH. Los CORE son tránsito puro: no tienen LAN propias ni prestan servicios a hosts (sin VRRP, DHCP, DNS ni NAT); solo ejecutan OSPF.

**Autenticación OSPF**

Toda la red interna usa OSPF en el área 0 (backbone) con autenticación MD5 y la clave `G4-OSPF-26`, con identificador de clave `1`. La autenticación se aplica en todas las interfaces que forman adyacencias:

- CORE ↔ EDGE: CORE-1 ↔ EDGE y CORE-2 ↔ EDGE.
- CORE ↔ CORE: CORE-1 ↔ CORE-2.
- CORE ↔ DIST: los cuatro enlaces hacia DIST-1 y DIST-2.

Un router con clave o identificador distinto no forma adyacencia, por lo que no puede inyectar rutas en el área. R1 (EDGE) y R4 (DIST) deben configurar el mismo valor en su extremo de cada enlace. La clave tiene 10 caracteres, dentro del máximo de 16 que admite la autenticación MD5 de OSPF.

**Plano de control en CORE**

- Las loopbacks (`10.255.255.4/32` y `10.255.255.5/32`) se anuncian en el área 0 como interfaces pasivas y se usan como router-id.
- Todos los enlaces del CORE son punto a punto hacia routers, por lo que no hay interfaces hacia hosts que requieran declararse pasivas.
- Los CORE no redistribuyen rutas: solo reenvían el tráfico entre EDGE y DIST.

#### Política integrada del grupo

- **Usuarios y privilegios:** pendiente de consolidación. ISP-1/ISP-2 (R2): `admin` y `monitor` (solo lectura), sin credenciales personales.
- **Servicios a deshabilitar:** pendiente de consolidación. ISP-1/ISP-2 (R2): Telnet, FTP, HTTP y API deshabilitados; solo SSH.
- **Autenticación OSPF:** MD5 en el área 0 con una clave única para todas las adyacencias (EDGE, CORE y DIST), definida en la tabla de claves de autenticación.
- **Autenticación BGP:** TCP-MD5 con claves independientes para cada sesión eBGP, definidas en la tabla de claves de autenticación.
- **Autenticación VRRP:** VRRPv2 con autenticación `simple` y clave independiente por grupo (VRID 10 y VRID 20), definidas en la tabla de claves de autenticación.

### 1.4 Política de operación

#### Formato del change log

Cada cambio lógico se registra en la sección 6.1 con el siguiente formato:

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
| --- | --- | --- | --- | --- |

- **Fecha:** día del commit, en formato `YYYY-MM-DD`.
- **Responsable:** rol que hizo el cambio (`R1` … `R5`).
- **Cambio:** hash corto del commit seguido de su mensaje.
- **Motivo:** por qué se hizo el cambio (tarea del backlog, defecto del diagrama o falla que corrige).
- **Cómo se revierte:** en documentación, `git revert <hash>`; en configuración, el comando inverso en el router o la restauración del backup anterior al cambio, indicando el archivo de `backups/`.

**Convención de commits (cátedra):** `tipo(alcance): descripción`, en español y sin punto final.

| Tipo | Uso |
| --- | --- |
| `feat` | Configuración nueva en un nodo (VRRP, OSPF, BGP, firewall, hosts) |
| `fix` | Corrección de una configuración o de un dato erróneo |
| `docs` | Memoria, backlog, IPAM y runbooks |
| `ops` | Operación: backups, restore, drills y monitoreo |
| `chore` | Estructura y mantenimiento del repositorio |

El alcance indica el área o el nodo afectado, por ejemplo `ipam`, `seguridad`, `vrrp`, `ospf`, `bgp`, `firewall`, `dist`, `backup`, `drill` o `backlog`.

- **Un commit por cambio lógico:** cada commit se puede revertir por separado sin arrastrar otros cambios. No se mezclan en un mismo commit cambios de distintos nodos o de distintos tipos.
- **Ramas:** cada rol trabaja en su rama (por ejemplo `docs/f0-r4-distribucion`) y la integra a `main` por pull request.
- **El change log refleja los commits del repo:** cada commit integrado a `main` tiene su fila en 6.1, con su hash corto en la columna Cambio. R5 actualiza la tabla después de cada merge. Los commits de merge no llevan fila propia; el PR se cita en la nota de la tabla. Si un commit de integración modifica el propio change log y su SHA todavía no está disponible, se registra provisionalmente en su propia fila mediante el mensaje único y el enlace/identificador del PR; la siguiente actualización reemplaza esa referencia por el SHA real. Nunca se inventa un hash.

#### Política de backup

**Cuándo**

| Momento | Sufijo del archivo |
| --- | --- |
| Snapshot BASE: topología levantada, antes de configurar | `base` |
| Al cerrar F1 (IPs, loopbacks y hardening) | `f1` |
| Al cerrar F2 (VRRP y OSPF) | `f2` |
| Al cerrar F3 (BGP y firewall) | `f3` |
| Antes y después de cada drill | `pre-drillN` / `post-drillN` |

**Generación, revisión y publicación**

En cada hito, el responsable prepara un export de texto `.rsc` y un backup binario completo `.backup`, con nombre `router_YYYY-MM-DD_<hito>`. Antes de compartir el export, lo inspecciona y sanitiza: el repositorio público puede contener únicamente `.rsc` sanitizados y metadatos no sensibles. Nunca se publican archivos `.backup`, exports `show-sensitive` ni exports completos que expongan secretos. La política no implica que se haya realizado ninguna captura: a F0 hay cero backups reales y cero ejecución de CLI de RouterOS.

El backup binario es un artefacto sensible y se guarda cifrado fuera del repositorio público, en almacenamiento privado con acceso controlado. La versión de RouterOS importa: desde RouterOS 6.43, el binario no se cifra si no se proporciona explícitamente una contraseña; por eso la protección debe configurarse de forma explícita y no depender de un valor predeterminado. La contraseña se gestiona por un canal privado y nunca se registra en el repositorio ni junto al localizador del artefacto. Un backup completo puede incluir credenciales de usuarios y claves privadas SSH. Los exports completos con `show-sensitive` también se consideran sensibles y se custodian cifrados, fuera del repositorio y con acceso controlado.

Los artefactos públicos y privados de hitos anteriores se conservan sin sobrescribirlos. Los `.rsc` sanitizados se versionan en el repositorio para que `git diff` permita revisar los cambios de configuración; cada hito se registra con un commit `ops(backup): ...` y se anota en 6.1 y 6.2. El traslado se realiza por SCP/SFTP mediante un canal seguro, sin guardar contraseñas ni otros secretos en el repositorio. Para cada artefacto privado se registra solamente un localizador privado no secreto, checksum, versión de RouterOS, router/propietario, fecha e hito, y resultado de revisión o restore. Las capturas y salidas de verificación se redactan antes de incorporarlas a la documentación.

R5 toma y coordina el snapshot BASE de los siete routers. En los hitos posteriores, el responsable de cada router prepara sus propios backups y exports; R5 coordina los hitos y verifica los metadatos de los siete equipos antes de darlos por cerrados.

**Restore y límites de recuperación**

En F1 se probará la recuperación en el mismo dispositivo y con la misma versión de RouterOS que los del backup privado. La evidencia incluirá el resultado y comparación con el export sanitizado correspondiente, sin revelar secretos. La restauración completa depende del artefacto privado: para usar el `.rsc` público como base de recuperación habrá que inyectar las claves exclusivas de laboratorio por el protocolo privado y volver a provisionar los usuarios de gestión. El export sanitizado no puede restaurar por sí solo secretos omitidos.

No se usarán credenciales personales ni se reutilizarán credenciales de otros servicios. Las claves ficticias ya documentadas en 1.3 solo son admisibles en un laboratorio aislado; no deben convertirse en claves personales ni reutilizarse fuera de él.

**Fuentes**

- MikroTik, [Backup](https://help.mikrotik.com/docs/spaces/ROS/pages/40992852/Backup), consultado el 2026-10-01. Desde RouterOS 6.43, si no se indica contraseña explícita, el backup binario no queda cifrado.
- MikroTik, [Configuration Management](https://help.mikrotik.com/docs/spaces/ROS/pages/328155/Configuration+Management), consultado el 2026-10-01. Los exports no incluyen contraseñas de usuarios del sistema, certificados instalados, claves SSH ni bases de datos de Dude/User Manager; se recomienda importar en la misma versión de RouterOS.

---

## 2. Topología

La topología de diseño se basa en la arquitectura de cinco capas definida por la consigna:

```text
[INTERNET]      ISP-1 (AS 65001)   ISP-2 (AS 65002)
                    \               /
[EDGE]               EDGE (AS 65000)
                         /      \
[CORE]              CORE-1 ---- CORE-2
                      |\          /|
                      | \        / |
                      |  \      /  |
                      |   \    /   |
                      |    \  /    |
                      |     \/     |
                      |     /\     |
                      |    /  \    |
                      |   /    \   |
                      |  /      \  |
                      | /        \ |
                      |/          \|
[DISTRIBUTION]      DIST-1       DIST-2
                      |\          /|
                      | \        / |
                      |  \      /  |
                      |   \    /   |
                      |    \  /    |
                      |     \/     |
                      |     /\     |
                      |    /  \    |
                      |   /    \   |
                      |  /      \  |
                      | /        \ |
                      |/          \|
[ACCESS]          SW-USERS    SW-SERVERS
                      |            |
                   PC-USER        SRV
```

La imagen definitiva de la topología se incorporará en `docs/diagramas/` una vez disponible el proyecto GNS3 provisto para el laboratorio.

---

## 3. Configuración

> Esta sección se completará después de la aprobación de F0. Según la regla de la consigna, no se realizará configuración CLI antes de aprobar el diseño.

### 3.1 ISP-1

Pendiente.

### 3.2 ISP-2

Pendiente.

### 3.3 EDGE

Pendiente.

### 3.4 CORE-1

Pendiente.

### 3.5 CORE-2

Pendiente.

### 3.6 DIST-1

Pendiente.

### 3.7 DIST-2

Pendiente.

### 3.8 Hosts (PC-USER / SRV)

Pendiente.

---

## 4. Verificación

### 4.1 Conectividad básica

Pendiente de las fases de implementación.

### 4.2 Los 5 drills de failover

Pendiente de F4.

---

## 5. Seguridad aplicada

Pendiente de las fases de implementación.

---

## 6. Gestión operativa

### 6.1 Change log

Formato y convención de commits: ver 1.4.

| Fecha | Responsable | Cambio | Motivo | Cómo se revierte |
| --- | --- | --- | --- | --- |
| 2026-10-01 | R1 | `5979210` chore(repo): crea estructura inicial del laboratorio | Estructura del repositorio pedida por la consigna | `git revert 5979210` |
| 2026-10-01 | R1 | `2b56d18` docs(ipam): define direccionamiento de EDGE y enlaces WAN | F0: IPAM de EDGE y corrección de los defectos 1 y 2 del diagrama | `git revert 2b56d18` |
| 2026-10-01 | R1 | `e9d9e22` docs(seguridad): define politica de seguridad del EDGE | F0: usuarios, servicios, firewall y claves BGP TCP-MD5 de EDGE | `git revert e9d9e22` |
| 2026-10-01 | R1 | `3fc9883` docs(ipam): asigna router-id de EDGE | F0: router-id de EDGE independiente de las interfaces físicas | `git revert 3fc9883` |
| 2026-10-01 | R4 | `01688e5` docs(ipam): define enlaces CORE-DIST y direccionamiento de LAN USERS/SERVERS | F0: direccionamiento de distribución y LAN sin solapamiento | `git revert 01688e5` |
| 2026-10-01 | R4 | `c7831a1` docs(ipam): define VRRP (VRID 10/20, prioridades) y router-id de DIST-1/DIST-2 | F0: gateway redundante con load-sharing entre DIST-1 y DIST-2 | `git revert c7831a1` |
| 2026-10-01 | R4 | `2334260` docs(seguridad): define claves VRRP y politica de hardening de DIST | F0: autenticación VRRP y hardening de distribución | `git revert 2334260` |
| 2026-10-01 | R4 | `784ea3e` docs(memoria): documenta correccion HSRP en core a VRRP en distribucion | F0: corrección del defecto 3 del diagrama | `git revert 784ea3e` |
| 2026-10-01 | R3 | `8b25741` docs(ipam): define enlace core-core y router-id de CORE | F0: enlace core–core para OSPF y router-id de CORE | `git revert 8b25741` |
| 2026-10-01 | R3 | `4bf6ab5` docs(seguridad): define clave OSPF MD5 y politica de hardening de CORE | F0: autenticación OSPF del área 0 y hardening de CORE | `git revert 4bf6ab5` |
| 2026-10-01 | R3 | `ddddd0c` docs(memoria): documenta correccion de enlace core-core faltante | F0: corrección del defecto 4 del diagrama | `git revert ddddd0c` |
| 2026-10-01 | R5 | `7fcfaed` docs(operacion): define formato de change log y politica de backup | F0: política de operación (1.4) | `git revert 7fcfaed` |
| 2026-10-01 | R5 | `decde1c` docs(backlog): arma backlog de F0 a F5 con tareas por rol | F0: backlog con dueño por tarea | `git revert decde1c` |
| 2026-10-01 | R5 | `a634504` docs(changelog): registra los commits de F0 y deja pendiente la evidencia de backup | R5: registra los commits F0 y la evidencia de backup pendiente; PR #4 | `git revert a634504` |
| 2026-10-01 | R1 — FerrariAgustinNicolas (integración) | Referencia prevista al integrar: `docs(operacion): protege backups publicos y ajusta trazabilidad F0` (PR #4; todavía no integrado) | Política pública de backup segura y estado veraz de HA y seguridad en F0 | Una vez integrado, localizar el SHA real con `git log --all --format='%H %s'` y revertirlo con `git revert <SHA verificado>` |

> Los aportes de R4 y R3 se integraron a `main` por los PR #1 (merge `58db8cd`) y #2 (merge `5427689`). Para revertir un aporte completo: `git revert -m 1 <hash del merge>`.
>
> Los commits de R2 ya existentes en la rama `docs/f0-r2-proveedores` quedan pendientes de integración a `main` y de registro aquí.

### 6.2 Backups

Política: ver 1.4.

**Pendiente de F1.** La evidencia se carga en esta sección a medida que se toman los backups:

- **Registro de backups:** una fila por router e hito (BASE, F1, F2, F3 y drills), con fecha, versión de RouterOS, propietario, checksum, resultado y referencia a un localizador privado no secreto. Solo los `.rsc` inspeccionados y sanitizados y los metadatos no sensibles pueden estar en el repositorio público; los `.backup` y exports sensibles permanecen cifrados fuera del repositorio y bajo acceso controlado.
- **Restore probado (F1):** router y versión coincidente, referencia privada al artefacto, resultado y comparación con el export sanitizado; documentar el protocolo privado para reinyectar las claves de laboratorio y provisionar usuarios de gestión. Las capturas y salidas se redactan; no se registran contraseñas ni rutas secretas.

### 6.3 Monitoreo

Pendiente R5.

---

## 7. Capturas

Pendiente.

---

## 8. Conclusiones y lecciones aprendidas

Pendiente de la finalización del laboratorio.

---

## 9. Referencias

Pendiente de completar con los recursos efectivamente utilizados.

---

## 10. Checklist de entrega

### Diseño (F0)

- [ ] IPAM completo y sin solapamiento
- [ ] Corrección del diagrama justificada (≥ 3 defectos)
- [ ] Política de seguridad definida (usuarios, servicios, claves)
- [ ] Política de operación definida (change log + backup)

### Redes

- [ ] 7 CHR + 2 switches + 2 hosts levantados y cableados
- [ ] VRRP operativo (2 grupos, load-sharing)
- [ ] OSPF área 0 con adyacencias (incluido core-core)
- [ ] BGP eBGP ×2 establecido (multi-homing)
- [ ] Los 5 drills ejecutados y documentados

### Seguridad

- [ ] Hardening aplicado
- [ ] OSPF MD5 funcionando
- [ ] BGP TCP-MD5 funcionando
- [ ] VRRP auth funcionando
- [ ] Firewall edge aplicado
- [ ] Prueba con clave incorrecta documentada

### Operación

- [ ] Change log completo
- [ ] Backups con restore probado
- [ ] Monitoreo habilitado y documentado
- [ ] Runbook por drill + post-mortem global

### Entrega

- [ ] Memoria completa
- [ ] Repo git con estructura correcta y commits por rol
- [ ] `backlog.md` con todas las tareas en done
- [ ] Capturas organizadas
- [ ] Cada integrante puede defender su parte y una parte ajena
