# Memoria del Laboratorio — Failover Routing

**Grupo:** 4  
**Materia:** Gestión Operativa y Seguridad en Redes (GOYS)
**Vencimiento de F0:** viernes 02/10/2026

**Fecha de entrega final:** viernes 23/10/2026

## Integrantes y roles

| Integrante | Rol |
| --- | --- |
| Ferrari Agustin Nicolas | R1 — Líder / Edge-WAN |
| Siadore Valentino | R2 — Proveedores |
| Kloster Agustin Ignacio | R3 — Core |
| Guarino Naim | R4 — Distribución |
| Bellomo Lorenzo | R5 — Hosts / QA / Operación |

---

## 1. Diseño (F0)

### 1.1 Corrección del diagrama

La consigna identifica cinco problemas en el diseño original. Se aplican cuatro correcciones de diseño; el SPOF de EDGE queda como recomendación de producción, fuera del mínimo F0. El diseño F0 está integrado en `main` (PR #1 a #4); la aprobación formal de la cátedra todavía no fue otorgada.

| # | Defecto detectado | Corrección aplicada | Justificación |
| :-: | --- | --- | --- |
| 1 | Firewall sin par de alta disponibilidad, generando un punto único de falla (SPOF). | Recomendación para producción: utilizar un par de firewalls en alta disponibilidad/failover. No se aplica en este laboratorio, que conserva un solo EDGE. | Un único firewall puede interrumpir la conectividad entre la red interna e Internet ante una falla del dispositivo. Un par redundante permite mantener el servicio si uno de los equipos queda fuera de operación. |
| 2 | iBGP Route Reflector mal ubicado en el diseño original. | Se utiliza eBGP directamente entre EDGE (AS 65000) e ISP-1 (AS 65001) / ISP-2 (AS 65002), sin Route Reflector. | Los proveedores pertenecen a sistemas autónomos diferentes, por lo que corresponde utilizar eBGP. En esta topología no existe necesidad de incorporar un Route Reflector iBGP. |
| 3 | HSRP en el core (diseño *collapsed*): el gateway redundante de las LAN vive en el core, que además hace de tránsito. | El primer salto redundante se mueve a distribución con VRRP: DIST-1 es master del grupo 10 (USERS) y DIST-2 del grupo 20 (SERVERS). El core queda como tránsito puro, solo con OSPF. | Cada capa cumple una función: el core solo reenvía y no concentra servicios de LAN. La falla de un gateway afecta a una sola LAN y no al core. VRRPv2 se define en RFC 3768 y VRRPv3 en RFC 5798; las opciones de autenticación son específicas de la implementación, no una garantía del estándar. HSRP es propietario de Cisco. Con dos grupos se reparte la carga entre DIST-1 y DIST-2. |
| 4 | Sin enlace core–core: CORE-1 y CORE-2 no están conectados directamente, por lo que solo se comunican a través de EDGE o de una DIST. | Se agrega el enlace CORE-1 ↔ CORE-2 (`10.255.0.16/30`, CORE-1 `.17` / CORE-2 `.18`) en el área 0 de OSPF, con autenticación MD5. | El enlace permite tránsito directo entre cores y evita depender de DIST para ese camino; no garantiza que OSPF lo prefiera sin validar costos. La preferencia se revisará en F2, sin fijar costos en F0. |
| 5 | Subredes superpuestas en el direccionamiento del diseño. | Se asignan nueve redes `/30` disjuntas, dos LAN y siete loopbacks `/32`. | Auditoría aritmética de las 33 asignaciones: 18 redes únicas y 153 pares comparados, sin superposición. Corrección integrada por R1–R4; no implica despliegue en GNS3. |

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
| ISP-1 ↔ EDGE | `10.255.0.0/30` | ISP-1: `10.255.0.1` / `ether1` | EDGE: `10.255.0.2` / `ether1` |
| ISP-2 ↔ EDGE | `10.255.0.4/30` | ISP-2: `10.255.0.5` / `ether1` | EDGE: `10.255.0.6` / `ether2` |
| EDGE ↔ CORE-1 | `10.255.0.8/30` | EDGE: `10.255.0.9` / `ether3` | CORE-1: `10.255.0.10` / `ether1` |
| EDGE ↔ CORE-2 | `10.255.0.12/30` | EDGE: `10.255.0.13` / `ether4` | CORE-2: `10.255.0.14` / `ether1` |
| CORE-1 ↔ CORE-2 | `10.255.0.16/30` | CORE-1: `10.255.0.17` / `ether2` | CORE-2: `10.255.0.18` / `ether2` |
| CORE-1 ↔ DIST-1 | `10.255.0.20/30` | CORE-1: `10.255.0.21` / `ether3` | DIST-1: `10.255.0.22` / `ether1` |
| CORE-1 ↔ DIST-2 | `10.255.0.24/30` | CORE-1: `10.255.0.25` / `ether4` | DIST-2: `10.255.0.26` / `ether1` |
| CORE-2 ↔ DIST-1 | `10.255.0.28/30` | CORE-2: `10.255.0.29` / `ether3` | DIST-1: `10.255.0.30` / `ether2` |
| CORE-2 ↔ DIST-2 | `10.255.0.32/30` | CORE-2: `10.255.0.33` / `ether4` | DIST-2: `10.255.0.34` / `ether2` |
| USERS | `192.168.10.0/24` | DIST-1: `192.168.10.2` / `ether3` · DIST-2: `192.168.10.3` / `ether3` | Gateway VRRP: `192.168.10.1` · PC-USER: `192.168.10.100` |
| SERVERS | `192.168.20.0/24` | DIST-1: `192.168.20.2` / `ether4` · DIST-2: `192.168.20.3` / `ether4` | Gateway VRRP: `192.168.20.1` · SRV: `192.168.20.100` |

> **Aporte R4 — enlaces CORE ↔ DIST:** se continúa la numeración consecutiva de `/30` a partir del bloque que sigue a EDGE. El enlace CORE-1 ↔ CORE-2 usa `10.255.0.16/30`, confirmado por R3. Convención: el CORE toma la primera IP utilizable y el DIST la segunda de cada `/30`.
>
> **Direccionamiento de las LAN:** en cada LAN, `.1` es la IP virtual VRRP (gateway de los hosts), `.2` es DIST-1, `.3` es DIST-2 y `.100` es el host.

> **Aporte R3 — enlace CORE ↔ CORE:** se utiliza el bloque reservado `10.255.0.16/30` para CORE-1 ↔ CORE-2, con CORE-1 en `.17` y CORE-2 en `.18`, siguiendo la convención de que el dispositivo con menor numeración toma la primera IP utilizable. Se confirman las direcciones del lado CORE propuestas por R4 en los enlaces CORE ↔ DIST.

> Las interfaces se relevaron durante F1 en el proyecto GNS3 `topologia_failover_routing` y se completaron con el mapeo validado en 2.2 (nombres de RouterOS; en GNS3, `eN` corresponde a `ether(N+1)`). No cambian las direcciones ni las decisiones del diseño F0. Los números de interfaz observados en el diagrama de ejemplo no se consideran vinculantes para el diseño del grupo.

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
| Intervalo de anuncios | 1 s | Con prioridad 100, intervalo teórico de caída 3,609375 s; no es una medición. |
| Versión | VRRPv2 | RFC 3768 define VRRPv2; RFC 5798 define VRRPv3. |
| Autenticación | `simple`; ver sección 1.3 | Opción de implementación RouterOS, no garantía de autenticidad frente a atacantes. |

RFC 3768 eliminó la autenticación de VRRP como mecanismo de seguridad; `simple` solo aporta detección de mismatch accidental, no defensa contra atacantes. MikroTik documenta las opciones de autenticación de su implementación ([VRRP](https://help.mikrotik.com/docs/spaces/ROS/pages/81362945/VRRP), consultado el 2026-10-01). Validar compatibilidad en la misma imagen de RouterOS durante F1. Para prioridad 100 y anuncios de 1 s, 3,609375 s es el intervalo teórico de caída (`3 × 1 + (256 − 100) / 256`), no una medición.

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

Las siete loopbacks están asignadas en el bloque reservado y son únicas; las interfaces físicas se relevaron durante F1 (tabla de enlaces y 2.2).

#### Sesiones eBGP

> **Aporte R2 — Proveedores:** revisión de las dos sesiones eBGP entre EDGE y los proveedores.

| Sesión | Extremo EDGE | Extremo ISP | Subred | Autenticación | Anuncio del ISP hacia EDGE |
| --- | --- | --- | --- | --- | --- |
| EDGE ↔ ISP-1 | `10.255.0.2` · AS 65000 · RID `10.255.255.3` | `10.255.0.1` · AS 65001 · RID `10.255.255.1` | `10.255.0.0/30` | TCP-MD5 `G4-BGP-ISP1-26` | `default-originate` (`0.0.0.0/0`) |
| EDGE ↔ ISP-2 | `10.255.0.6` · AS 65000 · RID `10.255.255.3` | `10.255.0.5` · AS 65002 · RID `10.255.255.2` | `10.255.0.4/30` | TCP-MD5 `G4-BGP-ISP2-26` | `default-originate` (`0.0.0.0/0`) |

- Las sesiones se establecen entre las IP de los enlaces `/30` (eBGP directo, sin multihop), no entre loopbacks: si el enlace cae, la sesión cae con él.
- Cada sesión usa su propia clave TCP-MD5, con el mismo valor en ambos extremos.
- Cada ISP anuncia su default y su loopback de Internet (`10.255.255.1/32` o `10.255.255.2/32`) hacia EDGE. El diseño F3 propaga el default activo de EDGE a la red interna por OSPF y las rutas LAN por BGP para el retorno. EDGE distribuye los destinos loopback de los ISP al interior mediante redistribución OSPF controlada y filtrada: mientras un proveedor esté conectado, su loopback se alcanza por ese proveedor. No se afirma que el otro ISP alcance el loopback de un proveedor desconectado. Un default BGP por sí solo no prueba salud de Internet aguas arriba; los drills F4 siguen pendientes.
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

Las claves VRRP son independientes por grupo y tienen 8 caracteres para el mecanismo `simple` de la implementación RouterOS; RFC 3768 no define autenticación VRRP como garantía de seguridad.

#### Política integrada de administración (los siete routers)

En los siete routers, `admin` se reserva para configuración y `monitor` para monitoreo/verificación de solo lectura. En RouterOS, `monitor` requiere únicamente las políticas mínimas `read` y `ssh`: no debe tener `write`, `policy`, `password`, `sensitive`, `reboot`, `ftp`, `test` ni `sniff`. Las credenciales de gestión serán exclusivas del laboratorio, privadas y no publicadas; quedan prohibidas credenciales personales o reutilizadas.

SSH es el único servicio de administración elegido para todos los routers. Se deshabilitan Telnet, FTP, HTTP/HTTPS (incluido WebFig), API/API-SSL y Winbox, además de administración MAC no autenticada y RoMON si no son necesarios. La consola de GNS3 se usa para bootstrap. SSH solo acepta fuentes/interfaces de gestión autorizadas; no se habilita escucha de gestión en WAN, USERS ni SERVERS. Las fuentes/interfaces concretas se relevarán y validarán en F1, sin inventar una subred.

La política de firewall de EDGE separa cadenas: en `input`, permitir `established/related`, BGP TCP/179 solo con ISP-1/ISP-2, OSPF (protocolo IP 89) solo con vecinos CORE y SSH solo desde gestión autorizada; rechazar el resto de entrada no solicitado. En `forward`, permitir USERS/SERVERS hacia los loopbacks simulados de ISP y el tráfico de retorno correspondiente; no aplicar un rechazo genérico que bloquee nuevas conexiones salientes. Reglas concretas quedan para F3.

#### Aporte R1 — EDGE/WAN

**Usuarios y privilegios**

En EDGE se utilizarán cuentas diferenciadas según su función:

- `admin`: cuenta administrativa destinada a tareas de configuración.
- `monitor`: cuenta con privilegios de solo lectura destinada a monitoreo y verificación.

No se utilizarán cuentas compartidas con credenciales personales de los integrantes.

**Servicios de administración**

R1 conservaba SSH o Winbox como opciones restringidas al plano de gestión. La decisión consolidada F0 es SSH-only en todos los routers; Winbox queda deshabilitado. El alcance de gestión nunca incluye los enlaces de proveedores.

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

El diseño del firewall de EDGE separa `input` de `forward`. En `input`, permite `established/related`, BGP TCP/179 solo con ISP-1/ISP-2, OSPF IP/89 solo con vecinos CORE y SSH solo desde gestión autorizada; rechaza el resto de entrada no solicitado. En `forward`, permite USERS/SERVERS hacia los loopbacks ISP simulados y el retorno correspondiente, sin bloquear genéricamente nuevas conexiones salientes. Puede registrar eventos relevantes para verificación y troubleshooting. Las reglas concretas se implementarán en F3, luego de la aprobación del diseño F0.

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

La autenticación `simple` viaja en texto claro dentro del segmento: aporta detección de mismatch accidental, no protección contra un atacante con acceso al enlace. Se conserva esta limitación para la sección 5. DIST-1 y DIST-2 deben configurar el mismo valor en cada grupo.

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

- **Usuarios y privilegios:** los siete routers usan `admin` para configuración y `monitor` para lectura/SSH mínimos, sin permisos de escritura ni credenciales personales; credenciales de laboratorio privadas y no publicadas.
- **Servicios:** SSH-only; deshabilitar Telnet, FTP, HTTP/HTTPS, API/API-SSL y Winbox, además de administración MAC no autenticada y RoMON si no se necesitan. Consola GNS3 para bootstrap. El allowlist de gestión se define tras relevamiento F1; nada de gestión desde WAN o LAN de usuarios/servidores.
- **Autenticación OSPF:** MD5, clave única e ID 1 en el área 0, en todas las adyacencias (EDGE, CORE y DIST).
- **Autenticación BGP:** TCP-MD5 con claves independientes para cada sesión eBGP.
- **Autenticación VRRP:** VRRPv2 y `simple` con clave independiente por grupo (VRID 10 y 20), opción de implementación RouterOS a validar en F1 sobre la misma versión; mismatch accidental, no defensa contra atacantes.

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
- **El change log refleja los commits del repo:** se registran los commits sustantivos de diseño, configuración, operación y documentación del laboratorio, con su hash corto en la columna Cambio. R5 actualiza la tabla después de cada merge. Los commits cuyo único propósito es mantener o actualizar el propio change log no requieren una fila autorreferencial, para evitar que cada actualización exija otro commit que la registre. Los merges de PR no llevan fila propia: se resumen en la nota de integraciones de la tabla. Nunca se inventa un hash ni se crean filas prospectivas.

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

El esquema de diseño F0 está en [`docs/diagramas/f0-diseno.md`](diagramas/f0-diseno.md). Es un esquema Mermaid authored, no captura ni topología desplegada de GNS3; el ASCII anterior se conserva como referencia.

### 2.1 Topología desplegada en GNS3 (F1)

R1 desplegó el proyecto `topologia_failover_routing` en la única instancia GNS3 operativa del grupo (GNS3 2.2.61, en su equipo). Los routers son MikroTik CHR con RouterOS 7.16; los switches son *Ethernet switch* de GNS3 y los hosts, VPCS. La topología respeta las cinco capas del diseño F0, incluido el enlace CORE-1 ↔ CORE-2.

| Elemento | Cantidad | Nodos |
| --- | :-: | --- |
| Routers CHR | 7 | ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1, DIST-2 |
| Switches | 2 | SW-USERS, SW-SERVERS |
| Hosts VPCS | 2 | PC-USER, SRV |
| **Enlaces** | **15** | 9 router ↔ router, 4 DIST ↔ switch, 2 switch ↔ host |

Evidencia: [`topologia_11_nodos_15_enlaces.png`](../capturas/F1/01_topologia/topologia_11_nodos_15_enlaces.png) (vista general) y [`topologia_interfaces_GNS3.png`](../capturas/F1/01_topologia/topologia_interfaces_GNS3.png) (etiquetas de interfaz). En ambas capturas los routers y hosts figuran detenidos: documentan el cableado, no el estado operativo, que se acredita con las pruebas de 4.1.

### 2.2 Cableado y correspondencia de interfaces GNS3 ↔ RouterOS

GNS3 rotula las interfaces del CHR `e0`–`e3`; RouterOS las nombra `ether1`–`ether4`. La regla es `eN` → `ether(N+1)`. Se verificó cruzando tres fuentes: las etiquetas de la captura de GNS3, la interfaz y el comentario de cada dirección en los exports, y el ping exitoso entre ambos extremos de cada enlace (4.1).

| Enlace | Subred | Extremo A: GNS3 → RouterOS · IP | Extremo B: GNS3 → RouterOS · IP |
| --- | --- | --- | --- |
| ISP-1 ↔ EDGE | `10.255.0.0/30` | ISP-1 `e0` → `ether1` · `.1` | EDGE `e0` → `ether1` · `.2` |
| ISP-2 ↔ EDGE | `10.255.0.4/30` | ISP-2 `e0` → `ether1` · `.5` | EDGE `e1` → `ether2` · `.6` |
| EDGE ↔ CORE-1 | `10.255.0.8/30` | EDGE `e2` → `ether3` · `.9` | CORE-1 `e0` → `ether1` · `.10` |
| EDGE ↔ CORE-2 | `10.255.0.12/30` | EDGE `e3` → `ether4` · `.13` | CORE-2 `e0` → `ether1` · `.14` |
| CORE-1 ↔ CORE-2 | `10.255.0.16/30` | CORE-1 `e1` → `ether2` · `.17` | CORE-2 `e1` → `ether2` · `.18` |
| CORE-1 ↔ DIST-1 | `10.255.0.20/30` | CORE-1 `e2` → `ether3` · `.21` | DIST-1 `e0` → `ether1` · `.22` |
| CORE-1 ↔ DIST-2 | `10.255.0.24/30` | CORE-1 `e3` → `ether4` · `.25` | DIST-2 `e0` → `ether1` · `.26` |
| CORE-2 ↔ DIST-1 | `10.255.0.28/30` | CORE-2 `e2` → `ether3` · `.29` | DIST-1 `e1` → `ether2` · `.30` |
| CORE-2 ↔ DIST-2 | `10.255.0.32/30` | CORE-2 `e3` → `ether4` · `.33` | DIST-2 `e1` → `ether2` · `.34` |
| DIST-1 ↔ SW-USERS | `192.168.10.0/24` | DIST-1 `e2` → `ether3` · `.2` | SW-USERS |
| DIST-2 ↔ SW-USERS | `192.168.10.0/24` | DIST-2 `e2` → `ether3` · `.3` | SW-USERS |
| DIST-1 ↔ SW-SERVERS | `192.168.20.0/24` | DIST-1 `e3` → `ether4` · `.2` | SW-SERVERS |
| DIST-2 ↔ SW-SERVERS | `192.168.20.0/24` | DIST-2 `e3` → `ether4` · `.3` | SW-SERVERS |
| SW-USERS ↔ PC-USER | `192.168.10.0/24` | SW-USERS | PC-USER · `.100` |
| SW-SERVERS ↔ SRV | `192.168.20.0/24` | SW-SERVERS | SRV · `.100` |

En la captura, las etiquetas `e2` de DIST-1 y `e3` de DIST-2 quedan tapadas por otros rótulos. Se asignaron por descarte y coinciden con la interfaz LAN de cada export y con los pings de los hosts a ambos DIST (4.1). Los puertos de los switches no son legibles en todos los casos y no se documentan; los switches no tienen configuración. Con este relevamiento se completó la columna de interfaz de la tabla 1.2, sin cambiar direcciones ni decisiones del diseño F0.

### 2.3 Snapshot BASE

| Dato | Valor |
| --- | --- |
| Nombre | `F1_BASE_2026-10-08_sin-configurar` |
| Registro en GNS3 | 2026-10-08 16:40:13 (hora del equipo de R1) |
| Creado por | R1, antes de configurar los routers (informado por R1; el nombre del snapshot lo indica) |
| Tipo | Snapshot del proyecto GNS3 |
| Evidencia | [`snapshot_BASE_2026-10-08.png`](../capturas/F1/01_topologia/snapshot_BASE_2026-10-08.png) |

El snapshot BASE es un snapshot de GNS3, no un backup binario de RouterOS ni un export. La captura acredita que está registrado en el proyecto; no reemplaza al snapshot, a una copia portable del proyecto ni a un restore probado. El snapshot reside en el proyecto GNS3 de R1, sin copia portable registrada, y no se probó restaurarlo. Restaurarlo sobre el proyecto en uso revertiría la configuración F1.

---

## 3. Configuración

> **Estado F1 (08 y 09/10/2026):** R1 aplicó identidad, direcciones IP, loopbacks y hardening en los siete routers, y configuró los dos hosts. OSPF, BGP, VRRP y el firewall de EDGE no están configurados: corresponden a F2 y F3. No se recibió una aprobación expresa de F0 por parte de la cátedra.

### 3.0 Base común F1

#### Ejecución y verificación

La única instancia GNS3 operativa está en el equipo de R1, que ejecutó la configuración y las pruebas. R5 no operó la instancia: verificó las capturas y los exports, y los documentó.

| Actividad | Ejecución en GNS3 | Verificación y documentación | Evidencia |
| --- | --- | --- | --- |
| Despliegue de 11 nodos y 15 enlaces | R1 | R5: contrastó la topología con el diseño F0 | 2.1, 2.2 |
| Snapshot BASE | R1 | R5: registró nombre, fecha y alcance | 2.3 |
| Identidad, IP de enlace y loopback de los 7 routers | R1 | R5: contrastó capturas y exports con el IPAM 1.2 | 3.0, 2.2 |
| Pings de los 9 enlaces directos | R1 | R5: revisó resultado por enlace | 4.1 |
| Configuración de PC-USER y SRV y pings a ambos DIST | R1 | R5 | 3.8, 4.1 |
| Hardening de los 7 routers y eliminación de clientes DHCP heredados | R1 | R5: contrastó capturas finales y exports | 5.1 |
| Cambio de contraseña de `admin` en los 7 routers | R1 | R5: registró la confirmación de R1; no hay evidencia publicable | 5.1 |
| Generación de los exports `/export` | R1 | — | 6.2 |
| Publicación de los exports por PR | R1 (EDGE), R2 (ISP), R3 (CORE), R4 (DIST) | R5: revisó el contenido de los siete `.rsc` | 6.2 |
| Selección y organización de capturas | — | R5 | 7 |

#### Direccionamiento y loopbacks aplicados

Se aplicaron 31 de las 33 asignaciones del IPAM 1.2: las 18 direcciones de enlace, las 4 direcciones LAN de DIST, las 7 loopbacks y las 2 de los hosts. Las IP virtuales VRRP (`192.168.10.1` y `192.168.20.1`) se crean en F2. Todas las direcciones coinciden con el IPAM; cada router tiene `/system identity` igual a su nombre.

| Router | Direcciones de enlace y LAN | Loopback (`lo`) | Captura |
| --- | --- | --- | --- |
| ISP-1 | `ether1` `10.255.0.1/30` | `10.255.255.1/32` | [`ISP-1_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/ISP-1_IPAM_y_ping_EDGE.png) |
| ISP-2 | `ether1` `10.255.0.5/30` | `10.255.255.2/32` | [`ISP-2_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/ISP-2_IPAM_y_ping_EDGE.png) |
| EDGE | `ether1` `10.255.0.2/30` · `ether2` `10.255.0.6/30` · `ether3` `10.255.0.9/30` · `ether4` `10.255.0.13/30` | `10.255.255.3/32` | [`EDGE_IPAM_y_loopback.png`](../capturas/F1/02_ipam_y_conectividad/EDGE_IPAM_y_loopback.png) |
| CORE-1 | `ether1` `10.255.0.10/30` · `ether2` `10.255.0.17/30` · `ether3` `10.255.0.21/30` · `ether4` `10.255.0.25/30` | `10.255.255.4/32` | [`CORE-1_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/CORE-1_IPAM_y_ping_EDGE.png) |
| CORE-2 | `ether1` `10.255.0.14/30` · `ether2` `10.255.0.18/30` · `ether3` `10.255.0.29/30` · `ether4` `10.255.0.33/30` | `10.255.255.5/32` | [`CORE-2_IPAM_y_pings_EDGE_CORE-1.png`](../capturas/F1/02_ipam_y_conectividad/CORE-2_IPAM_y_pings_EDGE_CORE-1.png) |
| DIST-1 | `ether1` `10.255.0.22/30` · `ether2` `10.255.0.30/30` · `ether3` `192.168.10.2/24` · `ether4` `192.168.20.2/24` | `10.255.255.6/32` | [`DIST-1_IPAM_y_pings_CORE.png`](../capturas/F1/02_ipam_y_conectividad/DIST-1_IPAM_y_pings_CORE.png) |
| DIST-2 | `ether1` `10.255.0.26/30` · `ether2` `10.255.0.34/30` · `ether3` `192.168.10.3/24` · `ether4` `192.168.20.3/24` | `10.255.255.7/32` | [`DIST-2_IPAM_y_pings_CORE.png`](../capturas/F1/02_ipam_y_conectividad/DIST-2_IPAM_y_pings_CORE.png) |

Los mismos valores figuran en los exports de 6.2.

### 3.1 ISP-1

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/ISP-1_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-1_2026-10-09_f1.rsc). BGP pendiente de F3.

### 3.2 ISP-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/ISP-2_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-2_2026-10-09_f1.rsc). BGP pendiente de F3.

### 3.3 EDGE

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/EDGE_2026-10-09_f1.rsc`](../backups/2026-10-09/EDGE_2026-10-09_f1.rsc). OSPF pendiente de F2; BGP y firewall, de F3.

### 3.4 CORE-1

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/CORE-1_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-1_2026-10-09_f1.rsc). OSPF pendiente de F2.

### 3.5 CORE-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/CORE-2_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-2_2026-10-09_f1.rsc). OSPF pendiente de F2.

### 3.6 DIST-1

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/DIST-1_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-1_2026-10-09_f1.rsc). VRRP y OSPF pendientes de F2.

### 3.7 DIST-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/DIST-2_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-2_2026-10-09_f1.rsc). VRRP y OSPF pendientes de F2.

### 3.8 Hosts (PC-USER / SRV)

R1 configuró ambos hosts VPCS según el IPAM 1.2:

| Host | LAN | IP/máscara | Gateway | Captura |
| --- | --- | --- | --- | --- |
| PC-USER | USERS | `192.168.10.100/24` | `192.168.10.1` | [`PC-USER_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/PC-USER_IP_y_pings_DIST.png) |
| SRV | SERVERS | `192.168.20.100/24` | `192.168.20.1` | [`SRV_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/SRV_IP_y_pings_DIST.png) |

El gateway de cada host es la IP virtual VRRP, que se crea en F2: en F1 todavía no responde y no se usa como prueba. La conectividad F1 de los hosts se prueba contra las direcciones reales de DIST-1 y DIST-2 (4.1). DNS no se configuró porque no es necesario.

---

## 4. Verificación

### 4.1 Conectividad básica

#### F1: enlaces directos y hosts

R1 ejecutó estas pruebas después de asignar las direcciones; R5 revisó cada captura. Las capturas no muestran fecha y corresponden a la verificación inicial. R1 informó que, después de eliminar los clientes DHCP heredados, repitió con éxito los pings de los nueve enlaces; esa segunda prueba no tiene captura y estas imágenes no la documentan.

**Enlaces directos entre routers** (`/ping <IP> count=4`):

| # | Enlace | Origen → destino | Resultado | Captura |
| :-: | --- | --- | --- | --- |
| 1 | ISP-1 ↔ EDGE | ISP-1 → `10.255.0.2` | 4/4, 0 % de pérdida | [`ISP-1_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/ISP-1_IPAM_y_ping_EDGE.png) |
| 2 | ISP-2 ↔ EDGE | ISP-2 → `10.255.0.6` | 4/4, 0 % de pérdida | [`ISP-2_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/ISP-2_IPAM_y_ping_EDGE.png) |
| 3 | EDGE ↔ CORE-1 | CORE-1 → `10.255.0.9` | 4/4, 0 % de pérdida | [`CORE-1_IPAM_y_ping_EDGE.png`](../capturas/F1/02_ipam_y_conectividad/CORE-1_IPAM_y_ping_EDGE.png) |
| 4 | EDGE ↔ CORE-2 | CORE-2 → `10.255.0.13` | 4/4, 0 % de pérdida | [`CORE-2_IPAM_y_pings_EDGE_CORE-1.png`](../capturas/F1/02_ipam_y_conectividad/CORE-2_IPAM_y_pings_EDGE_CORE-1.png) |
| 5 | CORE-1 ↔ CORE-2 | CORE-2 → `10.255.0.17` | 4/4, 0 % de pérdida | ídem 4 |
| 6 | CORE-1 ↔ DIST-1 | DIST-1 → `10.255.0.21` | 4/4, 0 % de pérdida | [`DIST-1_IPAM_y_pings_CORE.png`](../capturas/F1/02_ipam_y_conectividad/DIST-1_IPAM_y_pings_CORE.png) |
| 7 | CORE-2 ↔ DIST-1 | DIST-1 → `10.255.0.29` | 4/4, 0 % de pérdida | ídem 6 |
| 8 | CORE-1 ↔ DIST-2 | DIST-2 → `10.255.0.25` | 4/4, 0 % de pérdida | [`DIST-2_IPAM_y_pings_CORE.png`](../capturas/F1/02_ipam_y_conectividad/DIST-2_IPAM_y_pings_CORE.png) |
| 9 | CORE-2 ↔ DIST-2 | DIST-2 → `10.255.0.33` | 4/4, 0 % de pérdida | ídem 8 |

**Hosts hacia ambos DIST** (`ping` de VPCS, 5 solicitudes):

| Origen → destino | Resultado | Captura |
| --- | --- | --- |
| PC-USER → DIST-1 `192.168.10.2` | 5/5 respuestas | [`PC-USER_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/PC-USER_IP_y_pings_DIST.png) |
| PC-USER → DIST-2 `192.168.10.3` | 5/5 respuestas | ídem |
| SRV → DIST-1 `192.168.20.2` | 5/5 respuestas | [`SRV_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/SRV_IP_y_pings_DIST.png) |
| SRV → DIST-2 `192.168.20.3` | 5/5 respuestas | ídem |

Alcance: estas pruebas acreditan conectividad en cada segmento directo. Sin OSPF ni BGP no hay enrutamiento entre segmentos; los pings entre LAN, entre loopbacks o hacia los ISP se verifican en F2 y F3.

### 4.2 Los 5 drills de failover

Pendiente de F4.

---

## 5. Seguridad aplicada

### 5.1 Hardening F1 (los siete routers)

R1 aplicó el hardening en los siete routers. R5 lo verificó con las capturas finales del 09/10 (una por router), las capturas previas de administración MAC, Neighbor Discovery y RoMON (08/10, según R1) y los exports del 09/10. El cambio de contraseña de `admin` se registra como confirmación de R1. Política de referencia: 1.3.

| Control | Estado verificado en los 7 routers | Evidencia |
| --- | --- | --- |
| Servicios IP `telnet`, `ftp`, `www`, `www-ssl`, `api`, `api-ssl`, `winbox` y `ssh` | Los ocho deshabilitados | Capturas `*_hardening_final_2026-10-09.png` (`/ip service print`); `/ip service` en los exports |
| Bandwidth Server | `enabled: no` | Capturas finales; `/tool bandwidth-server set enabled=no` en los exports del 09/10 |
| MAC Telnet y MAC Winbox | `allowed-interface-list: none` | Capturas `*_MAC_neighbor_RoMON.png`; `/tool mac-server` en los exports |
| MAC Ping | `enabled: no` | Capturas `*_MAC_neighbor_RoMON.png`; exports |
| Neighbor Discovery | `discover-interface-list: none` | Capturas `*_MAC_neighbor_RoMON.png`; exports |
| RoMON | `enabled: no` | Capturas `*_MAC_neighbor_RoMON.png`. Es el valor por defecto, por eso no figura en el export |
| Usuario `monitor` | Existe, en el grupo `monitor` con políticas `ssh,read`; el resto de las políticas, negadas | Capturas finales (`/user print`, `/user group print`); definición del grupo en los exports |
| Clientes DHCP heredados | Eliminados: ningún export del 09/10 contiene `/ip dhcp-client` | Exports; en EDGE, cambio visible en el commit `247101e` |
| Identidad | `/system identity` igual al nombre del router | Capturas finales y exports |
| Contraseña de `admin` | Cambiada en los 7 routers: no conserva la contraseña de fábrica | Confirmación de R1 en la revisión de la PR #14 (2026-10-09). No hay captura ni export que la muestre, porque las credenciales no se publican y el export no incluye usuarios |

Para EDGE, las capturas de administración MAC, Neighbor Discovery y RoMON están en [`EDGE_neighbor_discovery_deshabilitado.png`](../capturas/F1/04_hardening/EDGE/EDGE_neighbor_discovery_deshabilitado.png); para ISP-1, en [`ISP-1_servicios_MAC_neighbor_RoMON.png`](../capturas/F1/04_hardening/ISP-1/ISP-1_servicios_MAC_neighbor_RoMON.png). El índice completo está en la sección 7.

**SSH temporalmente deshabilitado.** La política 1.3 define SSH como único servicio de administración, restringido a fuentes de gestión autorizadas. Ese origen todavía no está definido, por lo que SSH permanece deshabilitado en los siete routers y la administración se hace solo por la consola de GNS3. El usuario `monitor` existe, pero su acceso remoto no está operativo. Queda pendiente definir el origen de gestión autorizado y habilitar SSH restringido a él.

**Consola de GNS3.** Los títulos de ventana `telnet localhost <puerto>` corresponden a la consola virtual de GNS3, no al servicio Telnet de RouterOS, que está deshabilitado. Los puertos de consola cambian entre sesiones de GNS3; el router se identifica por el prompt y por `/system identity print`.

**Credenciales.** No se publican. Los exports `.rsc` no incluyen usuarios ni contraseñas: la existencia de `monitor` se acredita por captura y el cambio de contraseña de `admin`, por confirmación de R1. La recuperación de credenciales requiere el procedimiento privado de 6.2.

**Pendiente de fases siguientes:** autenticación OSPF MD5 y VRRP (F2); BGP TCP-MD5 y firewall de EDGE (F3).

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
| 2026-10-01 | R1 — FerrariAgustinNicolas (integración) | `e58fee3` docs(operacion): protege backups publicos y ajusta trazabilidad F0 | F0: protege artefactos privados y aclara HA pendiente; PR #4 | `git revert e58fee3` |
| 2026-10-01 | R2 | `753d82f` docs(ipam): asigna router-id de ISP-1 e ISP-2 | F0: completa loopbacks y router-id de proveedores | `git revert 753d82f` |
| 2026-10-01 | R2 | `2045a23` docs(bgp): documenta sesiones eBGP EDGE-ISP con default-originate | F0: documenta peers, claves y anuncios de proveedores | `git revert 2045a23` |
| 2026-10-01 | R2 | `feaecc6` docs(seguridad): define politica de hardening y autenticacion BGP de ISP | F0: define hardening y autenticación de ISP | `git revert feaecc6` |
| 2026-10-01 | R1 — FerrariAgustinNicolas (integración PR #3) | `dd1b8ab` docs(f0): consolida diseno y seguridad preservando aportes por rol | Consolidación F0, corrección IPAM y diagrama; integrado por PR #3 (merge `e316152`) | `git revert dd1b8ab` (PR #3 completo: `git revert -m 1 e316152`) |
| 2026-10-01 | R1 — FerrariAgustinNicolas | `8f5d4f1` chore(repo): excluye archivos locales del entorno | Evita versionar archivos locales de herramientas; integrado por PR #5 (merge `531056f`) | `git revert 8f5d4f1` |
| 2026-10-02 | R5 | `91454d7` docs(f0): actualiza tracking y change log tras integracion | F0: estado del backlog y del checklist tras integrar PR #1 a #4; PR #6 (merge `49510c6`) | `git revert 91454d7` |
| 2026-10-02 | R5 | `3f12c89` docs(f0): cierra defecto 1 y evita autorreferencia en change log | F0: cierre documental del defecto 1 y regla de filas del change log (1.4); PR #6 | `git revert 3f12c89` |
| 2026-10-02 | R5 | `a87eeb4` docs(backlog): ajusta tareas a la estructura de la consigna | Backlog alineado con las historias de la consigna; PR #7 (merge `07306e5`) | `git revert a87eeb4` |
| 2026-10-02 | R1 | `731ec42` docs(f0): corrige integrantes y presentacion de la memoria | Integrantes y presentación de README y memoria; PR #8 (merge `8741527`) | `git revert 731ec42` |
| 2026-10-08 | R1 | `4ebb2fb` ops(backup): incorpora export F1 de EDGE | F1: primer export de EDGE; PR #9 (merge `dbbe755`) | `git revert 4ebb2fb` |
| 2026-10-08 | R1 | `247101e` fix(backup): elimina cliente DHCP heredado de EDGE | F1: el export refleja la eliminación del cliente DHCP heredado; PR #9 | `git revert 247101e` |
| 2026-10-09 | R3 | `1e52151` ops(backup): incorpora exports F1 de CORE | F1: primeros exports de CORE-1/CORE-2; PR #10 (merge `6beba24`) | `git revert 1e52151` |
| 2026-10-09 | R1 | `2f4cf66` ops(backup): incorpora export F1 actualizado de EDGE | F1: export de EDGE del 09/10, con Bandwidth Server deshabilitado; PR #11 (merge `170975b`) | `git revert 2f4cf66` |
| 2026-10-09 | R2 | `60d0148` ops(backup): incorpora exports F1 de proveedores | F1: exports de ISP-1/ISP-2; PR #12 (merge `83119f5`) | `git revert 60d0148` |
| 2026-10-09 | R3 | `bbd594e` fix(backup): actualiza exports F1 de CORE tras hardening | F1: reemplaza los exports de CORE del 08/10 por los del 09/10, con Bandwidth Server deshabilitado; PR #10 | `git revert bbd594e` |
| 2026-10-09 | R4 — naimguar (PR #13) | `2309460` ops(backup): incorpora exports F1 de distribucion | F1: exports de DIST-1/DIST-2; PR #13 (merge `703c5b9`) | `git revert 2309460` |
| 2026-10-09 | R5 | `982fc39` docs(capturas): organiza evidencias F1 seleccionadas | F1: 26 capturas de R1 seleccionadas y organizadas en `capturas/F1/`; rama `docs/f1-r5-evidencias-operacion` | `git revert e154b47` |
| 2026-10-09 | R5 | `2d293ca` docs(memoria): documenta despliegue, conectividad, hardening y exports de F1 | F1: memoria 2.1–2.3, 3, 4.1, 5.1, 6.2 y 7.1; misma rama | `git revert 96dcdeb` |
| 2026-10-09 | R5 | `cd8c8d5` docs(memoria): integra exports de DIST y checklist F1 tras PR #13 | F1: referencias a los exports de DIST y checklist F1 (10); misma rama | `git revert 9643d08` |
| 2026-10-09 | R5 | `f80979d` docs(backlog): marca tareas F1 respaldadas por evidencia | F1: estado de las tareas F1 con evidencia; misma rama | `git revert 610d04c` |

> Integraciones a `main` (merges): PR #1 (R4) `58db8cd`, PR #2 (R3) `5427689`, PR #4 (R5) `e35fdeb`, PR #3 (R2 y consolidación) `e316152`, PR #5 (`.gitignore`) `531056f`, PR #6 (R5) `49510c6`, PR #7 (R5) `07306e5`, PR #8 (R1) `8741527`, PR #9 (R1) `dbbe755`, PR #11 (R1) `170975b`, PR #12 (R2) `83119f5`, PR #10 (R3) `6beba24` y PR #13 (R4) `703c5b9`. Los merges no llevan fila propia; para revertir un PR completo: `git revert -m 1 <merge>`, por ejemplo `git revert -m 1 e316152` (PR #3) o `git revert -m 1 e35fdeb` (PR #4).
>
> `be128f7` fue un merge histórico de `main` hacia la rama de R2 (`docs/f0-r2-proveedores`) para integrar cambios. **No** es el merge final del PR #3: el merge final es `e316152`. Del mismo modo, `77d59a9` lleva `main` a la rama `docs/f1-r5-evidencias-operacion` después de la PR #13. Los commits individuales conservan su autoría y no se reescriben.
>
> Los commits de F1 publican exports, capturas y documentación. La configuración aplicada en los routers no tiene commit propio: se revierte con el comando inverso en la consola o, para volver al estado previo a F1, con el snapshot BASE de GNS3 (2.3), cuyo restore no fue probado.
>
> El commit `2309460` figura en git con autor "Claude"; la PR #13 la abrió R4 (naimguar). Las filas de la rama `docs/f1-r5-evidencias-operacion` corresponden a commits existentes; su merge a `main` sigue pendiente de la revisión de R1.

### 6.2 Backups

Política: ver 1.4.

A F0 no había backups reales: F0 solo exigía la política definida.

#### Exports F1 (`/export`)

Los exports se generaron en la instancia GNS3 de R1 y cada rol publicó los de sus routers por PR. Los siete del 09/10 son **posteriores** a la asignación de direcciones y al hardening: representan el estado F1 final, no el estado previo a la configuración. La fecha y hora son las que RouterOS escribe en la primera línea de cada export.

| Router | Archivo | Encabezado del export | Publicado por | Commit · PR | Estado |
| --- | --- | --- | --- | --- | --- |
| EDGE | [`backups/2026-10-09/EDGE_2026-10-09_f1.rsc`](../backups/2026-10-09/EDGE_2026-10-09_f1.rsc) | 2026-10-09 17:23:56 · RouterOS 7.16 | R1 | `2f4cf66` · PR #11 (merge `170975b`) | En `main` |
| ISP-1 | [`backups/2026-10-09/ISP-1_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-1_2026-10-09_f1.rsc) | 2026-10-09 17:24:45 · RouterOS 7.16 | R2 | `60d0148` · PR #12 (merge `83119f5`) | En `main` |
| ISP-2 | [`backups/2026-10-09/ISP-2_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-2_2026-10-09_f1.rsc) | 2026-10-09 17:25:21 · RouterOS 7.16 | R2 | `60d0148` · PR #12 (merge `83119f5`) | En `main` |
| CORE-1 | [`backups/2026-10-09/CORE-1_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-1_2026-10-09_f1.rsc) | 2026-10-09 17:03:17 · RouterOS 7.16 | R3 | `1e52151`, `bbd594e` · PR #10 (merge `6beba24`) | En `main` |
| CORE-2 | [`backups/2026-10-09/CORE-2_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-2_2026-10-09_f1.rsc) | 2026-10-09 17:04:37 · RouterOS 7.16 | R3 | `1e52151`, `bbd594e` · PR #10 (merge `6beba24`) | En `main` |
| DIST-1 | [`backups/2026-10-09/DIST-1_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-1_2026-10-09_f1.rsc) | 2026-10-09 17:25:52 · RouterOS 7.16 | R4 | `2309460` · PR #13 (merge `703c5b9`) | En `main` |
| DIST-2 | [`backups/2026-10-09/DIST-2_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-2_2026-10-09_f1.rsc) | 2026-10-09 17:26:33 · RouterOS 7.16 | R4 | `2309460` · PR #13 (merge `703c5b9`) | En `main` |

Versiones anteriores: [`backups/2026-10-08/EDGE_2026-10-08_f1.rsc`](../backups/2026-10-08/EDGE_2026-10-08_f1.rsc) (PR #9, merge `dbbe755`) es el export previo de EDGE, todavía sin `bandwidth-server enabled=no`. Se conserva como historial y lo reemplaza el del 09/10. Los exports de CORE del 08/10 se reemplazaron en `bbd594e` y quedan en el historial de git.

**Revisión R5 de los siete exports del 09/10** (los siete están en `main`; los de DIST integrados son idénticos a los revisados en la PR #13):

- `/system identity` coincide con el nombre del archivo.
- Direcciones y loopbacks coinciden con el IPAM 1.2 y con las capturas de 3.0.
- Hardening de 5.1: servicios IP, Bandwidth Server, administración MAC, Neighbor Discovery y grupo `monitor`.
- Ningún export contiene `/ip dhcp-client`.
- Ningún export contiene usuarios, contraseñas, claves ni salida `show-sensitive`.

En la captura final de DIST-1 se ve el comando `/export file=DIST-2_F1_2026-10-09`, ejecutado en DIST-1. El export publicado de DIST-1 corresponde a DIST-1, según su identidad y sus direcciones. El archivo con nombre equivocado, si existe, queda en el almacenamiento local de DIST-1 y no se publica.

#### Política interna de backup: procedimientos adicionales

La política 1.4 agrega procedimientos que van más allá del export inicial de F1. Su estado actual:

| Procedimiento (política 1.4) | Estado |
| --- | --- |
| Snapshot BASE | Registrado en GNS3 (2.3). No es un backup de RouterOS y no se probó su restore |
| Export `base` de cada router antes de configurar | No se generó |
| Backup binario `.backup` cifrado, fuera del repositorio | **Pendiente**: no hay evidencia de que se haya realizado |
| Registro de localizador privado, checksum y resultado de cada binario | **Pendiente**: depende del binario |
| Restore probado en un router con la misma versión de RouterOS | **Pendiente** |
| Procedimiento privado para reinyectar claves y reprovisionar usuarios | **Pendiente** |

Cuando se realicen, se registrarán aquí con los metadatos que exige 1.4: localizador privado no secreto, checksum, versión de RouterOS, propietario, fecha, hito y resultado.

Los `.rsc` publicados están sanitizados: no incluyen usuarios ni contraseñas, de modo que por sí solos no permiten recuperar las credenciales de gestión. Esa recuperación requiere el procedimiento privado, que todavía no está documentado. En el repositorio no se publican binarios, contraseñas ni localizadores secretos.

### 6.3 Monitoreo

Pendiente R5.

---

## 7. Capturas

### 7.1 F1

R1 tomó las capturas en su instancia GNS3 y las entregó a R5 sin editar. R5 seleccionó 26 de las 27 recibidas y las organizó en [`capturas/F1/`](../capturas/F1/). Las copias del repositorio son idénticas a las del paquete recibido (verificado por SHA-256). Las capturas de consola no muestran fecha; solo se indica fecha cuando la imagen o su origen la acreditan.

| Archivo (`capturas/F1/…`) | Qué demuestra | Sección |
| --- | --- | --- |
| `01_topologia/topologia_11_nodos_15_enlaces.png` | 7 CHR, 2 switches, 2 VPCS y 15 enlaces | 2.1 |
| `01_topologia/topologia_interfaces_GNS3.png` | Etiquetas de interfaz `e0`–`e3` de cada enlace | 2.2 |
| `01_topologia/snapshot_BASE_2026-10-08.png` | Snapshot `F1_BASE_2026-10-08_sin-configurar`, 2026-10-08 16:40:13 | 2.3 |
| `02_ipam_y_conectividad/ISP-1_IPAM_y_ping_EDGE.png` | IP y loopback de ISP-1; ping a EDGE | 3.0, 4.1 |
| `02_ipam_y_conectividad/ISP-2_IPAM_y_ping_EDGE.png` | IP y loopback de ISP-2; ping a EDGE | 3.0, 4.1 |
| `02_ipam_y_conectividad/EDGE_IPAM_y_loopback.png` | IP de los cuatro enlaces y loopback de EDGE | 3.0 |
| `02_ipam_y_conectividad/CORE-1_IPAM_y_ping_EDGE.png` | IP y loopback de CORE-1; ping a EDGE | 3.0, 4.1 |
| `02_ipam_y_conectividad/CORE-2_IPAM_y_pings_EDGE_CORE-1.png` | IP y loopback de CORE-2; pings a EDGE y CORE-1 | 3.0, 4.1 |
| `02_ipam_y_conectividad/DIST-1_IPAM_y_pings_CORE.png` | IP, LAN y loopback de DIST-1; pings a CORE-1 y CORE-2 | 3.0, 4.1 |
| `02_ipam_y_conectividad/DIST-2_IPAM_y_pings_CORE.png` | IP, LAN y loopback de DIST-2; pings a CORE-1 y CORE-2 | 3.0, 4.1 |
| `03_hosts/PC-USER_IP_y_pings_DIST.png` | Configuración de PC-USER; pings a DIST-1 y DIST-2 | 3.8, 4.1 |
| `03_hosts/SRV_IP_y_pings_DIST.png` | Configuración de SRV; pings a DIST-1 y DIST-2 | 3.8, 4.1 |
| `04_hardening/<router>/<router>_hardening_final_2026-10-09.png` (7) | Identidad, Bandwidth Server, servicios IP y usuario/grupo `monitor`, 09/10 | 5.1 |
| `04_hardening/<router>/<router>_MAC_neighbor_RoMON.png` (CORE-1, CORE-2, DIST-1, DIST-2, ISP-2) | Administración MAC, Neighbor Discovery y RoMON, 08/10 según R1 | 5.1 |
| `04_hardening/ISP-1/ISP-1_servicios_MAC_neighbor_RoMON.png` | Servicios IP, administración MAC, Neighbor Discovery y RoMON de ISP-1, 08/10 según R1 | 5.1 |
| `04_hardening/EDGE/EDGE_neighbor_discovery_deshabilitado.png` | Administración MAC y RoMON; cambio de Neighbor Discovery a `none` en EDGE, 08/10 según R1 | 5.1 |

**Excluida:** `EDGE_administracion_MAC.png`, del paquete de R1. Es un estado intermedio: muestra SSH todavía habilitado y la administración MAC antes y después del cambio. El estado final está cubierto por `EDGE_neighbor_discovery_deshabilitado.png` y por la captura final del 09/10. Queda fuera del repositorio, en el paquete original.

**Observación:** la captura final de DIST-1 conserva arriba el comando `/export file=DIST-2_F1_2026-10-09` (ver 6.2). No altera lo que la captura demuestra, pero conviene repetirla sin ese comando antes de la entrega definitiva.

---

## 8. Conclusiones y lecciones aprendidas

Pendiente de la finalización del laboratorio.

---

## 9. Referencias

Pendiente de completar con los recursos efectivamente utilizados.

---

## 10. Checklist de entrega

### Diseño (F0)

- **Diseño interno:** completado y documentado.
- **Integración Git:** completada (PR #1 `58db8cd`, PR #2 `5427689`, PR #4 `e35fdeb`, PR #3 `e316152`).
- **Aprobación formal de la cátedra:** no recibida de forma expresa.
- **F1:** ejecutada el 08 y 09/10/2026; estado en la lista F1 de esta sección.

- [x] IPAM de diseño: 9 enlaces `/30`, 2 LAN, 7 loopbacks `/32`, sin solapamiento (verificación matemática documentada)
- [x] Cuatro correcciones de diseño aplicadas; SPOF EDGE queda como recomendación
- [x] Política integrada de gestión, autenticación y servicios
- [x] Política de operación y change log documentados

### Topología, hardening y backup (F1)

F1 no se declara cerrada ni aprobada: la auditoría y la integración final corresponden a R1.

**Criterios de aceptación de F1** (estructura del backlog de la consigna):

- [x] 7 CHR + 2 switches + 2 hosts desplegados y cableados: 11 nodos y 15 enlaces (2.1, 2.2)
- [x] IP de enlace y loopbacks de los 7 routers según el IPAM; 9 enlaces directos probados (3.0, 4.1)
- [x] PC-USER y SRV configurados y con conectividad a ambos DIST (3.8, 4.1)
- [x] Snapshot BASE registrado en GNS3 antes de configurar (2.3). Es un snapshot de GNS3; no se probó su restore
- [x] Hardening de los 7 routers (5.1), incluido el cambio de contraseña de `admin` (confirmación de R1). SSH queda temporalmente deshabilitado
- [x] Backup inicial `/export` de los 7 routers, sanitizado e integrado en `main` (6.2)

**Procedimientos adicionales de la política interna de backup (1.4)**, no exigidos por los criterios anteriores:

- [ ] Backup binario `.backup` cifrado, fuera del repositorio, con metadatos registrados en 6.2
- [ ] Restore probado en un router con la misma versión de RouterOS
- [ ] Procedimiento privado para reinyectar claves y reprovisionar usuarios de gestión
- [ ] Export `base` de cada router antes de configurar: no se generó; solo existe el snapshot GNS3

El ítem "Backups con restore probado" de Operación sigue pendiente para la entrega final.

**Pendientes operativos de F1:**

- [ ] Definir el origen de gestión autorizado y habilitar SSH restringido a él
- [ ] Repetir la captura final de DIST-1 sin el comando `/export` previo (7.1)

### Redes

- [x] 7 CHR + 2 switches + 2 hosts levantados y cableados (F1, 2.1)
- [ ] VRRP operativo (2 grupos, load-sharing)
- [ ] OSPF área 0 con adyacencias (incluido core-core)
- [ ] BGP eBGP ×2 establecido (multi-homing)
- [ ] Los 5 drills ejecutados y documentados

### Seguridad

- [x] Hardening aplicado (F1, 5.1; SSH temporalmente deshabilitado)
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
- [ ] Capturas organizadas (F1 organizadas en 7.1; faltan las de F2–F4)
- [ ] Cada integrante puede defender su parte y una parte ajena
