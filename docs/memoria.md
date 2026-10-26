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

La consigna identifica cinco problemas en el diseño original. Se aplican cuatro correcciones de diseño; el SPOF de EDGE queda como recomendación de producción, fuera del mínimo F0. El diseño F0 está integrado en `main` (PR #1 a #4) y la cátedra lo devolvió como aprobado, 100/100 (devolución informada por R1).

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

> **Posterior a F1:** el 14/10 se agregó la red de gestión aislada `172.31.250.0/28`, que no se solapa con ningún bloque de esta tabla. No forma parte del diseño F0; su direccionamiento está en 2.4.

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

### 2.3 Snapshots GNS3 y recuperación del proyecto

| Dato | Snapshot BASE | Snapshot FINAL |
| --- | --- | --- |
| Nombre | `F1_BASE_2026-10-08_sin-configurar` | `F1_FINAL_2026-10-09` |
| Registro en GNS3 | 2026-10-08 16:40:13 (hora del equipo de R1) | 2026-10-09 23:35:42 (informado por R1) |
| Creado por | R1, antes de configurar los routers (informado por R1; el nombre del snapshot lo indica) | R1, al cierre de F1 |
| Tipo | Snapshot del proyecto GNS3 | Snapshot del proyecto GNS3 |
| Evidencia | [`snapshot_BASE_2026-10-08.png`](../capturas/F1/01_topologia/snapshot_BASE_2026-10-08.png) | Informada por R1; sin captura publicada |

Los snapshots son de GNS3, no backups binarios de RouterOS ni exports. La captura del BASE acredita que está registrado en el proyecto; no reemplaza al snapshot. Restaurar un snapshot sobre el proyecto en uso revertiría la configuración posterior. **El restore de snapshots individuales de GNS3 no se probó.**

#### Recuperación portable del proyecto

R1 exportó el proyecto como `topologia_failover_F1.gns3project` (unos 159 MB, sin compresión) y verificó el ZIP sin errores. El archivo contiene siete discos QEMU, los dos snapshots, dos configuraciones VPCS, la imagen CHR 7.16 y el archivo del proyecto. Contiene discos completos de los routers: no se publica en el repositorio.

- La importación estándar de GNS3 falló porque intentó usar GNS3 VM, que no está configurada en la Mac de R1. No se atribuye con certeza el problema del proyecto original a una causa concreta.
- El 2026-10-10 (fecha informada por R1), R1 recuperó el laboratorio extrayendo el archivo en una carpeta aislada y abriendo una copia independiente mediante el archivo `.gns3`. Luego creó una copia de trabajo con `Save project as`, con identificadores independientes.
- Resultado informado por R1: los siete routers arrancaron y conservaron IP, loopbacks y hardening; PC-USER y SRV conservaron IP y gateway y respondieron a DIST-1 y DIST-2; se verificó la conectividad EDGE–ISP-1.

Se validó la recuperación del estado del proyecto por esta vía; no se validó la importación estándar ni el restore de snapshots. Sin capturas publicadas.

### 2.4 Red de gestión SSH-MGMT (14/10/2026, posterior a F1)

Al cierre de F1 (09/10), SSH estaba deshabilitado en los siete routers porque no se había definido un origen de gestión autorizado (5.1). El 14/10, R1 implementó en GNS3 una red de gestión aislada para habilitar SSH de forma restringida. Las pruebas las hizo R1; R5 las documenta a partir de lo informado por R1 y de los exports publicados.

Sobre la topología F1 se agregaron dos nodos auxiliares, el switch **SW-MGMT** y el host **MGMT-CLIENT**, y ocho enlaces de gestión: uno por router y uno del cliente. La copia SSH-MGMT del proyecto queda con 13 nodos y 23 enlaces. No se modificó ningún enlace de producción: el cableado de 2.2 sigue igual.

| Nodo | Interfaz de gestión (RouterOS) | Dirección |
| --- | --- | --- |
| EDGE | `ether5` | `172.31.250.1/28` |
| ISP-1 | `ether2` | `172.31.250.2/28` |
| ISP-2 | `ether2` | `172.31.250.3/28` |
| CORE-1 | `ether5` | `172.31.250.4/28` |
| CORE-2 | `ether5` | `172.31.250.5/28` |
| DIST-1 | `ether5` | `172.31.250.6/28` |
| DIST-2 | `ether5` | `172.31.250.7/28` |
| MGMT-CLIENT | — | `172.31.250.10` (único origen autorizado) |

En los ISP la gestión usa `ether2`, la primera interfaz libre; en los demás routers usa `ether5`, porque `ether1`–`ether4` ya están ocupadas. Para la prueba de rechazo se usó un origen no autorizado, `172.31.250.11` (4.1). Las direcciones de la tabla figuran en los exports de `backups/2026-10-14/` (6.2). No se publicó una captura de la topología SSH-MGMT.

---

## 3. Configuración

> **Estado F1 (08 y 09/10/2026):** R1 aplicó identidad, direcciones IP, loopbacks y hardening en los siete routers, y configuró los dos hosts. OSPF, BGP, VRRP y el firewall de EDGE no están configurados: corresponden a F2 y F3. F0 fue devuelto por la cátedra como aprobado, 100/100; F1 se inició antes de recibirse esa devolución. F1 también fue aprobado, 100/100 (10).
>
> **Posterior a F1 (14/10/2026):** R1 agregó la red de gestión SSH-MGMT en los siete routers (2.4 y 3.9). Las secciones 3.0 a 3.8 describen el estado al 09/10 y no se reescribieron.
>
> **F2 (16/10/2026):** R1 configuró VRRP en DIST-1 y DIST-2 y OSPF en los cinco routers internos (3.10). Las menciones "pendiente de F2" de 3.3 a 3.7 corresponden al estado anterior y se conservan.

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
| Backups binarios cifrados, snapshot `F1_FINAL_2026-10-09`, copia portable y restore de ISP-1 | R1 | R5: documentó lo informado por R1; sin acceso directo a los binarios | 2.3, 6.2 |
| Selección y organización de capturas | — | R5 | 7 |
| Red SSH-MGMT y pruebas de acceso SSH (14/10) | R1 | R5: contrastó lo informado por R1 con los siete exports | 2.4, 3.9, 4.1, 5.2 |
| Publicación de los exports SSH-MGMT por PR | R1 (EDGE), R2 (ISP), R3 (CORE), R4 (DIST) | R5: revisó el contenido de los siete `.rsc` | 6.2 |
| Backups binarios SSH-MGMT (15/10) y restore aislado de ISP-1 (16/10) | R1 | R5: documentó lo informado por R1 y revisó las capturas; sin acceso directo a los binarios | 6.2, 7.2 |

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

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/ISP-1_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-1_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/ISP-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/ISP-1_2026-10-14_SSH_MGMT.rsc). BGP pendiente de F3.

### 3.2 ISP-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/ISP-2_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-2_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/ISP-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/ISP-2_2026-10-14_SSH_MGMT.rsc). BGP pendiente de F3.

### 3.3 EDGE

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/EDGE_2026-10-09_f1.rsc`](../backups/2026-10-09/EDGE_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/EDGE_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/EDGE_2026-10-14_SSH_MGMT.rsc). OSPF pendiente de F2; BGP y firewall, de F3.

### 3.4 CORE-1

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/CORE-1_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-1_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/CORE-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/CORE-1_2026-10-14_SSH_MGMT.rsc). OSPF pendiente de F2.

### 3.5 CORE-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/CORE-2_2026-10-09_f1.rsc`](../backups/2026-10-09/CORE-2_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/CORE-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/CORE-2_2026-10-14_SSH_MGMT.rsc). OSPF pendiente de F2.

### 3.6 DIST-1

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/DIST-1_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-1_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/DIST-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/DIST-1_2026-10-14_SSH_MGMT.rsc). VRRP y OSPF pendientes de F2.

### 3.7 DIST-2

F1: base común de 3.0 y hardening de 5.1. Export: [`backups/2026-10-09/DIST-2_2026-10-09_f1.rsc`](../backups/2026-10-09/DIST-2_2026-10-09_f1.rsc). Gestión SSH-MGMT desde el 14/10 (3.9): [`backups/2026-10-14/DIST-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/DIST-2_2026-10-14_SSH_MGMT.rsc). VRRP y OSPF pendientes de F2.

### 3.8 Hosts (PC-USER / SRV)

R1 configuró ambos hosts VPCS según el IPAM 1.2:

| Host | LAN | IP/máscara | Gateway | Captura |
| --- | --- | --- | --- | --- |
| PC-USER | USERS | `192.168.10.100/24` | `192.168.10.1` | [`PC-USER_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/PC-USER_IP_y_pings_DIST.png) |
| SRV | SERVERS | `192.168.20.100/24` | `192.168.20.1` | [`SRV_IP_y_pings_DIST.png`](../capturas/F1/03_hosts/SRV_IP_y_pings_DIST.png) |

El gateway de cada host es la IP virtual VRRP, que se crea en F2: en F1 todavía no responde y no se usa como prueba. La conectividad F1 de los hosts se prueba contra las direcciones reales de DIST-1 y DIST-2 (4.1). DNS no se configuró porque no es necesario.

### 3.9 Gestión SSH-MGMT (14/10/2026)

R1 aplicó la misma configuración en los siete routers; solo cambian la interfaz y la dirección de gestión de cada uno (2.4). Respecto de los exports F1 del 09/10, la única línea modificada es la del servicio SSH; el resto son altas:

| Bloque | F1 (09/10) | SSH-MGMT (14/10) |
| --- | --- | --- |
| `/ip vrf` | — | VRF `MGMT` con la interfaz de gestión como única interfaz |
| `/ip address` | Enlaces, LAN y loopback | Se agrega la dirección de gestión, comentario `Red de gestion aislada` |
| `/ip firewall filter` | Sin reglas | Tres reglas `chain=input` sobre `in-interface=MGMT`: aceptar ICMP desde `172.31.250.10`, aceptar TCP/22 desde `172.31.250.10` (ambas hacia la dirección de gestión propia) y descartar el resto |
| `/ip service ssh` | `disabled=yes` | `address=172.31.250.10/32 vrf=MGMT` |
| `/ip ssh` | Valores por defecto | `strong-crypto=yes` |

La VRF separa la red de gestión de la tabla principal, donde F2 y F3 configurarán OSPF y BGP. El firewall solo filtra lo que entra por `MGMT`; las reglas de entrada de EDGE por las demás interfaces siguen pendientes para F3. Se conservan las direcciones de producción, las loopbacks y el hardening de F1. No hay clientes DHCP ni configuración de OSPF, BGP o VRRP.

### 3.10 VRRP y OSPF (F2, 16/10/2026)

R1 configuró y probó VRRP y OSPF en la topología SSH-MGMT de GNS3 (proyecto `topologia_failover_F1_SSH_MGMT`). R2, R3 y R4 revisaron y publicaron por PR los exports de sus routers, y R1 el de EDGE. R5 no operó la instancia: revisó las capturas y los exports y los documenta.

| Actividad | Ejecución en GNS3 | Revisión y publicación | Evidencia |
| --- | --- | --- | --- |
| VRRP en DIST-1 y DIST-2 | R1 | R4: exports de DIST, PR #25 | 3.10, 4.3 |
| OSPF en EDGE | R1 | R1: export de EDGE, PR #23 | 3.10, 4.3 |
| OSPF en CORE-1 y CORE-2 | R1 | R3: exports de CORE, PR #24 | 3.10, 4.3 |
| OSPF en DIST-1 y DIST-2 | R1 | R4: exports de DIST, PR #25 | 3.10, 4.3 |
| ISP-1 e ISP-2 (sin cambios de F2) | — | R2: exports de ISP, PR #26 | 6.2 |
| Pruebas de failover VRRP, conectividad, parada y arranque | R1 | R5: revisó las 17 capturas | 4.1, 4.3, 7.3 |
| Snapshots, exports y backups binarios de F2 | R1 | R5: registró los metadatos informados por R1 | 6.2 |

Frente a los exports SSH-MGMT del 14/10, los exports de F2 de los routers internos solo agregan líneas: no se modificó ni se quitó ninguna configuración anterior. Los exports de ISP-1 e ISP-2 son iguales a los del 14/10: los ISP no tienen OSPF ni BGP en F2.

#### VRRP

| Grupo | Interfaz VRRP | Interfaz física | IP virtual | DIST-1 | DIST-2 |
| --- | --- | --- | --- | --- | --- |
| USERS, VRID 10 | `vrrp-users-10` | `ether3` | `192.168.10.1/32` | Prioridad 150, master preferido | Prioridad 100 (valor por defecto), backup |
| SERVERS, VRID 20 | `vrrp-servers-20` | `ether4` | `192.168.20.1/32` | Prioridad 100 (valor por defecto), backup | Prioridad 150, master preferido |

En los cuatro casos, `version=2` y `authentication=simple`. El intervalo de anuncios es de 1 s, como se ve en las capturas de `/interface vrrp print` (4.3). La IP virtual de cada grupo está asignada en la interfaz VRRP de ambos DIST. Las direcciones y prioridades coinciden con el diseño de 1.2.

El preempt no figura en el export porque usa el valor por defecto de RouterOS. En la prueba de la Figura 3, DIST-2 recuperó el rol de master de SERVERS al rehabilitar su interfaz VRRP (4.3).

**Autenticación VRRP:** R1 confirmó que configuró las contraseñas de los dos grupos durante F2 y que quedaron ocultas al preparar los exports públicos. El export saneado acredita `authentication=simple` en los dos grupos de ambos DIST, pero no muestra la contraseña ni permite comprobar que coincida entre DIST-1 y DIST-2. La coincidencia se apoya en la confirmación de R1 y en los roles master/backup estables que se observaron (4.3). La prueba con clave incorrecta corresponde a F4.

#### OSPF

| Router | Router-ID | Interfaces con adyacencia (`type=ptp`, MD5, `auth-id=1`) | Interfaces pasivas |
| --- | --- | --- | --- |
| EDGE | `10.255.255.3` | `ether3` (CORE-1), `ether4` (CORE-2) | `lo` |
| CORE-1 | `10.255.255.4` | `ether1` (EDGE), `ether2` (CORE-2), `ether3` (DIST-1), `ether4` (DIST-2) | `lo` |
| CORE-2 | `10.255.255.5` | `ether1` (EDGE), `ether2` (CORE-1), `ether3` (DIST-1), `ether4` (DIST-2) | `lo` |
| DIST-1 | `10.255.255.6` | `ether1` (CORE-1), `ether2` (CORE-2) | `ether3` (USERS), `ether4` (SERVERS), `lo` |
| DIST-2 | `10.255.255.7` | `ether1` (CORE-1), `ether2` (CORE-2) | `ether3` (USERS), `ether4` (SERVERS), `lo` |

Los cinco routers usan la instancia `ospf-v2` (OSPFv2) y el área `backbone-v2`, con el `area-id` por defecto de RouterOS, `0.0.0.0`, que por eso no figura en el export. El router-id de cada uno es su loopback (1.2). Las siete adyacencias, incluida la core–core, usan autenticación MD5. En los exports públicos, la clave figura reemplazada por `REDACTED_F2_DO_NOT_USE`. Las interfaces LAN y las loopbacks se anuncian como pasivas: no forman adyacencias. No se configuraron costos: se usan los valores por defecto y no se analizó por separado la preferencia del enlace core–core que quedó abierta en 1.1.

En la interfaz de gestión `MGMT` no hay OSPF. ISP-1 e ISP-2 no participan de OSPF: la conectividad con los ISP y la salida a "Internet" corresponden a F3.

### 3.11 eBGP, anuncios, default por OSPF y firewall de EDGE (F3, 19 a 25/10/2026)

R5 configuró y probó F3 en su copia del proyecto GNS3 (`failover_F2`, importada de `failover_F2.gns3project`), en una VM Ubuntu con GNS3 2.2.61 y los siete CHR RouterOS 7.16. Lo hizo con asistencia de Claude, que operó la VM desde Windows. R1 autorizó cada etapa por separado después de revisar el checkpoint anterior. El proyecto Mac de R1 no se tocó. R5 tipeó en la consola las claves TCP-MD5 y las contraseñas de los backups, que no aparecen en ninguna salida.

| Etapa | Fecha (hora de la VM, UTC) | Routers modificados | Evidencia |
| --- | --- | --- | --- |
| Checkpoint 0: salud de F2 en la copia de R5 y snapshot `PRE_F3_R5_2026-10-18` | 19/10, 16:00 a 16:37 | Ninguno (solo `print`) | 4.4, 7.4 |
| Filtros BGP y sesiones eBGP con TCP-MD5 (cambios 1 a 10) | 19/10, desde las 17:00 | EDGE, ISP-1, ISP-2 | 4.4, 7.4 |
| Cambio de la clave TCP-MD5 coordinado con R1 | 19/10, 19:50 a 20:01 | EDGE, ISP-1, ISP-2 | 4.4 |
| EDGE anuncia las dos LAN a los ISP (cambio 11) | 23/10, 00:12 a 00:23 | EDGE | 4.4 |
| Default y loopbacks ISP hacia OSPF | 23/10, 02:42 a 02:52 | EDGE | 4.4 |
| Firewall de EDGE | 23/10, 20:47 a 21:31 | EDGE | 4.4, 5.3 |
| Caída y recuperación de ISP-1 y de ISP-2 | 23/10, 23:05 a 23:29 | ISP-1, ISP-2 (solo `ether1`, rehabilitada) | 4.4 |
| Snapshot final, respaldos y exports | 25/10, 14:15 a 17:06 | Ninguno | 6.2 |

Frente a los exports de F2, CORE-1, CORE-2, DIST-1 y DIST-2 no tienen cambios de configuración: reciben el default y las loopbacks ISP por OSPF, como rutas dinámicas. Ningún export de F3 quita configuración de F2 (6.2).

#### eBGP

| Sesión | EDGE | ISP | Conexión |
| --- | --- | --- | --- |
| EDGE ↔ ISP-1 | AS 65000, `10.255.0.2`, `ebgp-isp1` | AS 65001, `10.255.0.1`, `ebgp-edge` | Directa sobre el /30 (`multihop=no`), TCP-MD5, router-id = loopback |
| EDGE ↔ ISP-2 | AS 65000, `10.255.0.6`, `ebgp-isp2` | AS 65002, `10.255.0.5`, `ebgp-edge` | Igual |

Cada ISP origina el default con `default-originate=always` y anuncia su loopback desde la address-list `bgp-isp1-out` o `bgp-isp2-out`. El default de un ISP no prueba que haya "Internet" detrás: en el laboratorio, el destino externo son las loopbacks `10.255.255.1/32` y `10.255.255.2/32`.

**Filtros de ruteo.** Todos aceptan solo lo explícito y terminan con `reject`.

| Cadena | Router | Acepta |
| --- | --- | --- |
| `edge-in-isp1` / `edge-in-isp2` | EDGE, entrada | `0.0.0.0/0` y la loopback del ISP correspondiente |
| `edge-out-isp` | EDGE, salida a los dos ISP | `192.168.10.0/24` y `192.168.20.0/24` |
| `isp1-in-edge` / `isp2-in-edge` | ISP, entrada | Las dos LAN |
| `isp1-out-edge` / `isp2-out-edge` | ISP, salida | El default y su propia loopback |

**Anuncio de las LAN (cambio 11).** EDGE anuncia las LAN con `output.network=bgp-lan-out` en las dos conexiones. La address-list `bgp-lan-out` contiene `192.168.10.0/24` y `192.168.20.0/24`, que EDGE aprende por OSPF. No hay `redistribute` de OSPF a BGP, rutas blackhole ni estáticas. El filtro `edge-out-isp` sigue siendo la segunda barrera: aunque la lista cambiara, a los ISP solo saldrían esas dos LAN. Ni la red de gestión `172.31.250.0/28`, ni los /30, ni las loopbacks internas se anuncian.

#### Default y loopbacks ISP hacia OSPF

En EDGE, la instancia `ospf-v2` quedó con:
- `originate-default=if-installed`: anuncia el default solo si EDGE tiene uno activo, que viene de BGP;
- `out-filter-chain=edge-ospf-out`: la cadena acepta `10.255.255.1/32` y `10.255.255.2/32` y rechaza el resto.

El paso previsto `redistribute=bgp` no se aplicó. Con la cadena asociada, RouterOS 7.16 ya exportaba como externas las rutas que la cadena acepta. R5 se detuvo, documentó el estado y optó por omitir ese paso (opción A); R1 validó el resultado al aprobar la implementación de F3. Resultado: EDGE origina tres LSA externos (`0.0.0.0/0` y las dos loopbacks ISP, métrica 1, tipo 1), y los cinco routers OSPF tienen esos tres y ninguno más.

#### Firewall de EDGE

Quince reglas en `/ip firewall filter`: las tres de gestión de 5.2 y doce reglas `F3 FW`. El detalle y el alcance de cada regla están en 5.3.

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

#### SSH-MGMT: acceso autorizado y rechazo (14/10)

R1 ejecutó estas pruebas en la topología SSH-MGMT (2.4) sobre los siete routers. R5 registra el resultado informado por R1 y por las PR #18 a #21; no hay capturas de estas pruebas en el repositorio.

| Prueba | Origen | Resultado en los 7 routers |
| --- | --- | --- |
| Acceso SSH a la dirección de gestión del router | MGMT-CLIENT `172.31.250.10` | Exitoso |
| Acceso SSH desde un origen no autorizado | `172.31.250.11` | Rechazado |
| Conectividad de los enlaces de producción después del cambio | Pings entre vecinos directos, como en F1 | Conservada. En DIST, además, PC-USER y SRV siguieron alcanzando ambos DIST (PR #19) |

Estas pruebas no se repitieron en el restore aislado de ISP-1 (6.2), que no tiene enlaces con ningún otro nodo.

#### F2: gateways virtuales, tráfico entre LAN y loopback de EDGE (16 y 17/10)

R1 ejecutó estas pruebas con OSPF y VRRP configurados; R5 revisó cada captura. Todas usan el `ping` de VPCS, con 5 solicitudes. La hora es la del nombre del archivo original de cada captura (7.3).

| Origen → destino | Resultado | Hora | Evidencia |
| --- | --- | --- | --- |
| PC-USER → gateway virtual `192.168.10.1` | 5/5 en dos pings seguidos | 16/10 17:28 | Figura 4 |
| SRV → gateway virtual `192.168.20.1` | 5/5 en dos pings seguidos | 16/10 17:20 | Figura 5 |
| PC-USER `192.168.10.100` → SRV `192.168.20.100` | 5/5, TTL 63 | 16/10 22:51 | Figura 11 (repetido en la 13) |
| SRV `192.168.20.100` → PC-USER `192.168.10.100` | 5/5, TTL 63 | 16/10 22:52 | Figura 12 (repetido en la 14) |
| PC-USER → loopback de EDGE `10.255.255.3` | 5/5, TTL 62 | 16/10 22:55 | Figura 13 |
| SRV → loopback de EDGE `10.255.255.3` | 5/5, TTL 62 | 16/10 22:57 | Figura 14 |
| PC-USER → SRV, después de la parada y el arranque | 5/5 | 17/10 01:44 | Figura 16 |

El TTL 63 entre las LAN indica un salto de router, el DIST que hace de gateway. El TTL 62 hacia EDGE indica dos saltos, DIST y CORE. Después del arranque solo se capturó el sentido PC-USER → SRV.

#### F3: hosts hacia las loopbacks ISP (23 y 25/10)

R5 ejecutó estas pruebas en su copia GNS3. Usan el `ping` y el `trace` de VPCS. La hora es la de la VM (UTC). El índice de evidencias está en 7.4.

| Origen → destino | Resultado | Hora | Evidencia |
| --- | --- | --- | --- |
| PC-USER → `10.255.255.1` y `10.255.255.2` | 5/5 y 5/5, TTL 61 | 23/10 02:59 a 03:03 | F3-12 |
| SRV → `10.255.255.1` y `10.255.255.2` | 5/5 y 5/5, TTL 61 | 23/10 02:59 a 03:03 | F3-12 |
| Traceroute de PC-USER a las dos loopbacks | `192.168.10.2` → CORE → `10.255.0.9` (EDGE) → loopback ISP | 23/10 02:59 a 03:03 | F3-12 |
| Traceroute de SRV a las dos loopbacks | `192.168.20.3` → CORE → EDGE (`10.255.0.9` o `10.255.0.13`) → loopback ISP | 23/10 02:59 a 03:03 | F3-12 |
| Las mismas cinco pruebas de ping, con el firewall aplicado | 5/5 cada una | 23/10 21:32 a 21:34 | F3-16 |
| PC-USER → las dos loopbacks y SRV; SRV → las dos loopbacks, después de los respaldos | 3/3 cada una | 25/10 17:05 a 17:06 | F3-29 |

- **TTL 61:** tres routers intermedios (DIST, CORE y EDGE).
- **Primer salto:** el DIST master de cada LAN según VRRP (DIST-1 en USERS, DIST-2 en SERVERS).
- **Segundo salto:** varía entre CORE-1 y CORE-2 por ECMP.
- **Último salto del traceroute:** responde `Destination port unreachable`, la respuesta normal de un destino a un traceroute UDP; confirma que se llegó.
- **Ruta de retorno:** cada ISP aprende las dos LAN por eBGP (4.4).

### 4.2 Los 5 drills de failover

Pendiente de F4. Las pruebas de failover VRRP de F2 (4.3) no son drills de F4: no siguieron un runbook ni midieron el tiempo de reconvergencia. Tampoco lo son las pruebas de caída y recuperación de ISP de F3 (4.4), que no midieron tiempos.

### 4.3 VRRP y OSPF (F2)

R1 ejecutó las pruebas en GNS3 el 16/10 y en la madrugada del 17/10. R5 revisó las 17 capturas (7.3) y las contrastó con los exports del 16/10 (6.2). La hora de cada captura es la del nombre del archivo original. La hora de los exports es la del encabezado de RouterOS.

#### VRRP: roles, failover y recuperación

| Prueba | Lo que muestra la captura | Hora | Evidencia |
| --- | --- | --- | --- |
| Roles en DIST-1 | USERS en MASTER con prioridad 150; SERVERS en BACKUP con prioridad 100. En el mismo historial, `vrrp-servers-20` aparece una vez como MASTER y luego vuelve a BACKUP. Termina con `/interface vrrp disable` sobre `vrrp-users-10` | 16/10 17:27 | Figura 1 |
| Roles en DIST-2 | SERVERS en MASTER con prioridad 150; USERS en BACKUP con prioridad 100 | 17/10 00:18 | Figura 2 |
| Failover y recuperación de SERVERS en DIST-2 | Se deshabilita y se rehabilita `vrrp-servers-20`. Al rehabilitarlo queda en BACKUP y, en la consulta siguiente, vuelve a MASTER | 16/10 17:23 | Figura 3 |
| Gateway de USERS desde PC-USER | Dos pings 5/5 a `192.168.10.1`. La captura no muestra el estado VRRP. Por la hora, es posterior a la deshabilitación de `vrrp-users-10` de la Figura 1 | 16/10 17:28 | Figura 4 |
| Gateway de SERVERS desde SRV | Dos pings 5/5 a `192.168.20.1`. La captura no muestra el estado VRRP. Por la hora, es anterior a la recuperación de la Figura 3 | 16/10 17:20 | Figura 5 |

Las Figuras 4 y 5 muestran que el gateway virtual respondió. Por sí solas no permiten fijar en qué instante del failover se tomaron. R1 informó que verificó los estados MASTER/BACKUP, el failover y la recuperación en los dos grupos. Que el failover es reversible se apoya en la Figura 3 para SERVERS. Para USERS se apoya en la Figura 2, donde DIST-2 vuelve a figurar como BACKUP de USERS, y en el export de DIST-1, donde `vrrp-users-10` está habilitada. No se midió el tiempo de conmutación.

#### OSPF: adyacencias y rutas

| Router | Vecinos en `Full` | Hora | Evidencia |
| --- | --- | --- | --- |
| EDGE | CORE-1 (`10.255.255.4`) y CORE-2 (`10.255.255.5`) | 17/10 00:10 | Figura 6 |
| CORE-1 | EDGE, CORE-2, DIST-1 y DIST-2 | 17/10 00:12 | Figura 7 |
| CORE-2 | CORE-1, EDGE, DIST-2 y DIST-1 | 17/10 00:13 | Figura 8 |

Las Figuras 6 a 8 muestran las siete adyacencias del área 0, todas en `Full`: EDGE–CORE-1, EDGE–CORE-2, CORE-1–CORE-2, CORE-1–DIST-1, CORE-1–DIST-2, CORE-2–DIST-1 y CORE-2–DIST-2. No hay capturas tomadas en DIST-1 y DIST-2; sus adyacencias se ven desde ambos CORE. Las adyacencias tenían entre 13 s y 3 min, porque las capturas son posteriores al arranque que siguió a la Figura 15 (más abajo).

En la tabla de rutas de EDGE se observó lo siguiente:

- `192.168.10.0/24` y `192.168.20.0/24` se aprenden por OSPF con dos nexthops ECMP: `10.255.0.10` (CORE-1) y `10.255.0.14` (CORE-2), con distancia 110 (Figura 9, 17/10 00:15).
- La loopback de CORE-1 se aprende por CORE-1, y la de CORE-2 por CORE-2. Las de DIST-1 (`10.255.255.6`) y DIST-2 (`10.255.255.7`) se aprenden por ECMP a través de los dos CORE (Figura 10, 16/10 22:35).

Desde ambas LAN se alcanzó la loopback de EDGE (4.1, Figuras 13 y 14).

#### Parada, arranque y estabilidad

| Hora | Observación | Evidencia |
| --- | --- | --- |
| 17/10 00:06 | En GNS3, los nodos del proyecto figuran detenidos | Figura 15 |
| 17/10 00:10 a 00:18 | Con los nodos ya arrancados, las adyacencias OSPF están en `Full` (entre 13 s y 3 min de antigüedad) y DIST-2 conserva sus roles VRRP | Figuras 2, 6 a 8 |
| 17/10 01:40:58 | EDGE registra en el log `system,error,critical` dos mensajes: `router was rebooted without proper shutdown` y `kernel failure in previous boot` | Figura 17 |
| 17/10 01:44 | PC-USER alcanza a SRV: 5/5 | Figura 16 |
| 17/10 02:03 | EDGE tiene 22m16s de uptime, carga de CPU del 1 % y 300,4 MiB de memoria libre sobre 512 MiB | Figura 17 |

R1 informó una parada y un arranque controlados del proyecto, después de los cuales verificó la conectividad. Las capturas muestran además que EDGE se reinició cerca de las 01:41: el uptime de la Figura 17 coincide con la hora de los dos mensajes críticos. **La causa de esos mensajes no se determinó** y no se diagnostica en esta memoria. Queda registrada como incidencia abierta.

#### Matriz de aceptación de F2

| Criterio | Resultado | Evidencia |
| --- | --- | --- |
| VRRP USERS (VRID 10), master preferido DIST-1 | Cumplido | Figura 1; export de DIST-1 (3.10) |
| VRRP SERVERS (VRID 20), master preferido DIST-2 | Cumplido | Figuras 2 y 3; export de DIST-2 (3.10) |
| Load-sharing: cada DIST es master de un grupo y backup del otro | Cumplido | Figuras 1 y 2 |
| Failover y recuperación VRRP | Cumplido según la verificación de R1; recuperación de SERVERS visible en la Figura 3. Sin medición de tiempos | Figuras 1, 3, 4 y 5 |
| Autenticación simple de VRRP en los dos grupos | Cumplido: configurada en ambos DIST según el export; contraseñas confirmadas por R1, sin publicarse | 3.10 |
| Gateways virtuales accesibles desde los hosts | Cumplido: 5/5 | Figuras 4 y 5 |
| OSPFv2 área 0 en los cinco routers internos, con MD5 | Cumplido | Exports (3.10) |
| Siete adyacencias en `Full`, incluida la core–core | Cumplido | Figuras 6 a 8 |
| Rutas a las LAN y loopbacks en EDGE, con ECMP | Cumplido | Figuras 9 y 10 |
| PC-USER ↔ SRV en ambos sentidos | Cumplido: 5/5 | Figuras 11 y 12 |
| Ambas LAN → loopback de EDGE | Cumplido: 5/5 | Figuras 13 y 14 |
| Conectividad después de la parada y el arranque | Cumplido en el sentido PC-USER → SRV | Figura 16 |
| Exports de F2 de los siete routers | Cumplido | 6.2 |
| Backups binarios de F2 de los siete routers | Generados y preservados por R1 (SHA-512); restore no probado | 6.2 |
| Prueba con clave incorrecta (OSPF y VRRP) | Pendiente de F4 | — |
| Drills cronometrados | Pendiente de F4 | 4.2 |

### 4.4 BGP, firewall y caída de un ISP (F3)

R5 ejecutó todas las pruebas en su copia GNS3. La hora es la de la VM y la de RouterOS, ambas en UTC. Las evidencias son salidas de consola en texto, saneadas, más tres capturas de la lista de snapshots (7.4).

#### Checkpoint 0: F2 sana en la copia de R5 (19/10)

Antes de cualquier cambio, R5 verificó en la copia:
- los siete CHR con RouterOS 7.16;
- 7 adyacencias OSPF en `Full`, 4 en CORE-1 y 4 en CORE-2;
- los roles VRRP de diseño;
- 5/5 de PC-USER y SRV hacia su gateway virtual, entre sí y hacia la loopback de EDGE.

Después creó el snapshot `PRE_F3_R5_2026-10-18`. Evidencias: F3-1 y F3-2. SSH-MGMT no se probó en ese momento; se probó con el firewall (más abajo).

#### Sesiones eBGP y rutas recibidas (19/10 y 23/10)

| Router | Sesiones | Rutas BGP | Evidencia |
| --- | --- | --- | --- |
| EDGE | `ebgp-isp1-1` y `ebgp-isp2-1` en `established` | `0.0.0.0/0` vía ISP-1 (activo) y vía ISP-2 (respaldo), `10.255.255.1/32` vía ISP-1 y `10.255.255.2/32` vía ISP-2 | F3-3, F3-4, F3-5 |
| ISP-1 | `ebgp-edge-1` en `established` | **Exactamente** `192.168.10.0/24` y `192.168.20.0/24` vía `10.255.0.2`, desde el cambio 11 | F3-6 |
| ISP-2 | `ebgp-edge-1` en `established` | **Exactamente** las dos LAN vía `10.255.0.6` | F3-7 |

- Ningún ISP recibe la red de gestión, los /30 ni las loopbacks internas.
- Después de cada etapa, OSPF siguió con 7 adyacencias `Full` y VRRP con sus roles (F3-3, F3-4, F3-7).
- **Cambio de clave TCP-MD5 (19/10).** La clave cargada al principio en ISP-1 no era la aprobada en 1.3. R5 la reportó a R1 (checkpoint del 19/10) y el cambio se coordinó con R1. El log de EDGE muestra el cierre y el restablecimiento de las dos sesiones: ISP-1 a las 19:50 y 19:56, ISP-2 a las 19:58 y 20:01. La verificación posterior da las dos sesiones en `established` (F3-5). Los valores no se muestran en ninguna evidencia.
- **Exposición de una clave en la consola.** En RouterOS 7.16, `/routing bgp connection print` muestra `tcp-md5-key` en claro, aun en formato simple. Pasó una vez con la clave de ISP-1 al inicio de F3. Se sanearon las evidencias, se limpiaron las consolas y desde entonces no se imprimieron conexiones con clave: las sesiones se consultan con `/routing bgp session print`.

#### Default y loopbacks ISP en la red interna (23/10)

| Router | LSA externos | Rutas externas aprendidas por OSPF | Evidencia |
| --- | --- | --- | --- |
| EDGE | 3 propios | — | F3-10, F3-12 |
| CORE-1 / CORE-2 | 3 | `0.0.0.0/0`, `10.255.255.1/32` y `10.255.255.2/32` vía EDGE | F3-11 |
| DIST-1 / DIST-2 | 3 | Las mismas tres, en ECMP vía CORE-1 y CORE-2 | F3-11 |

Ningún router tiene rutas OSPF en `172.16.0.0/12`. Fuera de los /30, las LAN y las loopbacks, la única ruta OSPF que no es /32 es el default. No aparecen los /30 de los ISP ni el segundo default.

#### Firewall de EDGE (23/10)

Las reglas se aplicaron en tres pasos (F3-13 a F3-15). Cada script se verificó por md5 antes de ejecutarlo, porque la VM perdía caracteres al tipear bajo carga. Las cinco denegaciones se aplicaron en Safe Mode, con la confirmación condicionada a BGP = 2 y OSPF = 2. El detalle de las reglas está en 5.3.

| Prueba | Resultado | Evidencia |
| --- | --- | --- |
| BGP, OSPF y VRRP con el firewall aplicado | 2 sesiones `established`, 7 adyacencias `Full`, roles VRRP sin cambios | F3-16 |
| Hosts hacia las loopbacks ISP y entre LAN | 5/5 en las cinco pruebas | F3-16 |
| Drops sobre tráfico legítimo | Contadores de las reglas 10, 12, 13 y 14 en 0 | F3-16 |
| SSH autorizado desde MGMT-CLIENT (`172.31.250.10`) a EDGE | EDGE pide `password:`. Se abortó con Ctrl+C sin ingresar credenciales. La regla 1 subió de 0 a 17 paquetes | F3-17 |
| SSH no autorizado desde CORE-1 (`172.31.250.4`, VRF `MGMT`) | Sin respuesta en 25 s. La regla 2 subió de 9 a 16 paquetes | F3-18 |
| SSH desde el enlace de ISP-1 a `10.255.0.2` | Sin respuesta en 25 s. La regla 11 subió de 0 a 5 paquetes | F3-19 |

La regla 4 (BGP entrante) quedó con contador 0. El connection tracking muestra que las dos sesiones las inició EDGE, de modo que su tráfico entra por la regla 3 (`established`). La regla 4 cubre el caso en que el ISP inicie la sesión. No se reinició ninguna sesión para probarla, porque R1 pidió no modificar sesiones que funcionan.

#### Caída y recuperación de un ISP por vez (23/10)

Antes de las pruebas, R5 creó el snapshot `F3_FW_R5_2026-10-23` (F3-20) y registró una línea base igual al estado final de abajo (F3-21).
- **Cómo se simuló cada caída:** `/interface disable ether1` en el ISP y luego `/interface enable ether1`. No se modificó EDGE, ni las sesiones, ni los filtros, ni el firewall.
- **Detección:** en GNS3 el enlace virtual de EDGE sigue arriba, así que EDGE detecta la falla por el hold-time de BGP (3 min) y el log registra `HoldTimer expired`.
- ISP-2 recién se tocó cuando ISP-1 estaba recuperado y verificado.

| Fase | EDGE | CORE y DIST | Hosts | Evidencia |
| --- | --- | --- | --- | --- |
| ISP-1 caído (`disable` 23:05, `HoldTimer expired` 23:08:12) | 1 sesión. Default activo vía ISP-2 (`10.255.0.5`). Desaparece `10.255.255.1/32` | Mantienen el default. Solo `10.255.255.2/32`. 7 adyacencias `Full`. VRRP sin cambios | `10.255.255.2`: 5/5. A `10.255.255.1`, ISP-2 responde `Destination network unreachable`, como se espera según el diseño | F3-22, F3-23 |
| ISP-1 recuperado (`enable` 23:14, `Established` 23:15:01) | 2 sesiones. Vuelve `10.255.255.1/32`. Default activo otra vez vía ISP-1 | 3 LSA externos | Ambas loopbacks: 5/5 | F3-24 |
| ISP-2 caído (`disable` 23:20, `HoldTimer expired` 23:23:13) | 1 sesión. El default sigue vía ISP-1. Desaparece `10.255.255.2/32` | Mantienen el default. Solo `10.255.255.1/32`. 7 adyacencias `Full` | `10.255.255.1`: 5/5. A `10.255.255.2`, ISP-1 responde `Destination network unreachable` | F3-25 |
| ISP-2 recuperado (`enable` 23:29, `Established` 23:29:49) | 2 sesiones. Vuelve `10.255.255.2/32`. Default vía ISP-1 | 3 LSA externos, 7 adyacencias `Full` | PC-USER → `.1` 5/5 y → `.2` 4/5. SRV → `.1` 4/5 y → `.2` 5/5. PC-USER → SRV 5/5 | F3-26 |

Durante cada caída, el ISP que seguía en servicio recibió exactamente las dos LAN.

**Estado final (23:31 a 23:36), igual a la línea base:**
- 2 sesiones eBGP;
- default vía ISP-1, con ISP-2 de respaldo;
- 7 adyacencias `Full` y 3 LSA externos;
- DIST-1 master del VRID 10 y DIST-2 master del VRID 20;
- 15 reglas de firewall, ninguna inválida.

**Limitaciones de estas pruebas** (registradas a pedido de R1):
1. No se midieron tiempos precisos de reconvergencia. La carga de la VM osciló entre 8 y 14 y las mediciones no serían confiables. Estas pruebas no son los drills cronometrados de F4 (4.2).
2. En la verificación final hubo dos series de ping 4/5. Ocurrieron con latencias de 500 a 860 ms y la carga en 12–14, atribuidas a la saturación de la VM y no a la red. El resto de las series dio 5/5.
3. La elección del default vía ISP-1 no responde a una política de preferencia explícita. Con atributos BGP iguales, EDGE volvió a preferir ISP-1 al recuperarlo en lugar de mantener la ruta más antigua; lo más probable es el desempate por el router-id menor (`10.255.255.1`). No se configuró `local-pref` ni otro atributo.

#### Reinicio de la VM y verificación posterior (25/10)

Hacia las 15:27 del 25/10, entre los exports y los backups de cierre (6.2), la VM se saturó y quedó congelada. R5 la reinició y volvió a levantar los nodos.
- Los siete routers registraron `kernel failure in previous boot` y `router was rebooted without proper shutdown`. Son coherentes con un apagado en frío de QEMU.
- La configuración persistió: los backups de las 16:18 y la verificación de las 17:00 muestran el mismo estado que los exports de las 14:45.

**Verificación de las 17:00 a las 17:06** (F3-29):
- **BGP:** EDGE con 2 sesiones y cada ISP con 1. Default activo vía ISP-1, con ISP-2 de respaldo.
- **OSPF:** EDGE con 2 vecinos `Full`, CORE-1 y CORE-2 con 4 cada uno, DIST-2 con 2. Los cinco routers OSPF consultados tienen 3 LSA externos.
- **VRRP:** DIST-2 master del VRID 20 (prioridad 150) y backup del VRID 10.
- **Firewall:** EDGE con 15 reglas y el resto de los routers con las 3 de gestión.
- **Conectividad:** pings 3/3 de PC-USER y SRV a las dos loopbacks ISP, y de PC-USER a SRV.

DIST-1 no se pudo consultar a las 17:00 porque su consola había cerrado la sesión. Sus dos adyacencias se ven `Full` desde CORE-1 y CORE-2, y a las 14:56 era master del VRID 10. El resultado fue satisfactorio y no hubo que modificar ninguna configuración.

#### Matriz de aceptación de F3

| Criterio | Resultado | Evidencia |
| --- | --- | --- |
| eBGP EDGE ↔ ISP-1 y EDGE ↔ ISP-2 con TCP-MD5, en `established` | Cumplido | F3-3 a F3-5, F3-29 |
| Cada ISP anuncia su loopback /32 y el default; EDGE los acepta con filtros explícitos | Cumplido | F3-3, F3-4; exports (6.2) |
| EDGE anuncia solo USERS y SERVERS; los ISP tienen ruta de retorno | Cumplido | F3-6, F3-7 |
| Sin anuncio de la red de gestión ni redistribución BGP↔OSPF indiscriminada | Cumplido | F3-6 a F3-11 |
| Default activo y loopbacks ISP propagados por OSPF a CORE y DIST | Cumplido: 3 LSA externos | F3-10 a F3-12 |
| Hosts de USERS y SERVERS alcanzan las dos loopbacks ISP (ping y traceroute) | Cumplido | F3-12, F3-16, F3-29 |
| Firewall de EDGE: `input` separado de `forward`, BGP solo desde los peers ISP, OSPF solo desde CORE, SSH solo desde gestión y rechazo de lo no solicitado | Cumplido | F3-13 a F3-19; 5.3 |
| Gestión de EDGE no responde desde los enlaces ISP | Cumplido | F3-19 |
| F2 preservada (OSPF, VRRP, conectividad entre LAN) después de cada cambio | Cumplido | F3-3 a F3-26, F3-29 |
| Caída y recuperación controlada de cada ISP | Cumplido, sin medición de tiempos y con dos series 4/5 en la verificación final | F3-21 a F3-26 |
| Snapshot final, exports saneados y respaldos privados post-F3 | Cumplido; restore no probado | F3-27 a F3-29; 6.2 |
| Prueba con clave TCP-MD5 incorrecta | Pendiente de F4 | — |
| Drills cronometrados | Pendiente de F4 | 4.2 |

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

**SSH temporalmente deshabilitado (estado al 09/10).** La política 1.3 define SSH como único servicio de administración, restringido a fuentes de gestión autorizadas. Al cierre de F1 ese origen todavía no estaba definido, por lo que SSH quedó deshabilitado en los siete routers y la administración se hacía solo por la consola de GNS3. El usuario `monitor` existía, pero su acceso remoto no estaba operativo. Este pendiente se resolvió después de F1, el 14/10 (5.2).

**Consola de GNS3.** Los títulos de ventana `telnet localhost <puerto>` corresponden a la consola virtual de GNS3, no al servicio Telnet de RouterOS, que está deshabilitado. Los puertos de consola cambian entre sesiones de GNS3; el router se identifica por el prompt y por `/system identity print`.

**Credenciales.** No se publican. Los exports `.rsc` no incluyen usuarios ni contraseñas: la existencia de `monitor` se acredita por captura y el cambio de contraseña de `admin`, por confirmación de R1. La recuperación de credenciales requiere el procedimiento privado de 6.2.

**Pendiente de fases siguientes:** autenticación OSPF MD5 y VRRP (F2, resuelto en 3.10); BGP TCP-MD5 y firewall de EDGE (F3, resuelto en 5.3).

### 5.2 Plano de gestión SSH-MGMT (14/10/2026)

Con la red de gestión de 2.4, SSH quedó habilitado de forma restringida. Los controles se verifican en los siete exports del 14/10 (6.2) y en el restore aislado de ISP-1 (capturas de 7.2).

| Control | Estado en los 7 routers |
| --- | --- |
| Servicio SSH | Habilitado solo en la VRF `MGMT` y solo para `172.31.250.10/32` |
| Cifrado SSH | `strong-crypto=yes` |
| Firewall de entrada en `MGMT` | ICMP y SSH aceptados solo desde `172.31.250.10`; el resto, descartado |
| Telnet, FTP, `www`, `www-ssl`, API, API-SSL y Winbox | Siguen deshabilitados |
| Administración MAC, Neighbor Discovery, RoMON y Bandwidth Server | Sin cambios respecto de 5.1 |
| Usuario `monitor` | Sin cambios: grupo `monitor` con `ssh,read`. No se informó una prueba de SSH específica con esta cuenta |

Las reglas de firewall no reemplazan el firewall de EDGE de F3: solo protegen la interfaz de gestión. Las credenciales siguen sin publicarse.

### 5.3 Firewall de EDGE y TCP-MD5 (F3, 23/10/2026)

R5 aplicó el firewall en EDGE el 23/10, con la autorización de R1 y siguiendo la política de 1.3. Antes de empezar estaban solo las 3 reglas de gestión de 5.2, y NAT, mangle y raw estaban vacíos. Antes de modificar, R5 guardó un export y un backup cifrado de EDGE, que se custodian en privado (6.2).

**Objetos de soporte:**
- **Listas de interfaces:** `FW-WAN` (`ether1` y `ether2`, hacia los ISP) y `FW-LAN` (`ether3` y `ether4`, hacia CORE).
- **Address-lists:** `FW-ISP-PEERS` (`10.255.0.1` y `10.255.0.5`), `FW-CORE-PEERS` (`10.255.0.10` y `10.255.0.14`) y `FW-LAN-INTERNAS` (`192.168.10.0/24` y `192.168.20.0/24`).

| # | Cadena | Coincidencia | Acción | Comentario |
| --- | --- | --- | --- | --- |
| 0 | input | ICMP desde `172.31.250.10` a `172.31.250.1`, entrada por `MGMT` | accept | Gestión (5.2) |
| 1 | input | TCP/22 desde `172.31.250.10` a `172.31.250.1`, entrada por `MGMT` | accept | Gestión (5.2) |
| 2 | input | Entrada por `MGMT` | drop | Gestión (5.2) |
| 3 | input | `connection-state=established,related,untracked` | accept | F3 FW in: established/related |
| 4 | input | TCP/179 desde `FW-ISP-PEERS`, entrada por `FW-WAN` | accept | F3 FW in: BGP desde ISP |
| 5 | input | OSPF desde `FW-CORE-PEERS`, entrada por `FW-LAN` | accept | F3 FW in: OSPF desde CORE |
| 6 | input | ICMP, entrada por `FW-LAN` | accept | F3 FW in: ICMP interno |
| 7 | input | ICMP desde `FW-ISP-PEERS`, entrada por `FW-WAN` | accept | F3 FW in: ICMP desde peers ISP |
| 8 | forward | `connection-state=established,related,untracked` | accept | F3 FW fwd: established/related |
| 9 | forward | Origen `FW-LAN-INTERNAS`, salida por `FW-WAN`, `connection-state=new` | accept | F3 FW fwd: LAN hacia ISP |
| 10 | input | `connection-state=invalid` | drop | F3 FW deny in: invalid |
| 11 | input | Entrada por `FW-WAN` | drop | F3 FW deny in: WAN no solicitado |
| 12 | input | Resto | drop | F3 FW deny in: resto |
| 13 | forward | `connection-state=invalid` | drop | F3 FW deny fwd: invalid |
| 14 | forward | Entrada por `FW-WAN`, `connection-state=new` | drop | F3 FW deny fwd: nuevo desde WAN |

- La gestión sigue entrando solo por la VRF `MGMT` desde `172.31.250.10/32`. Telnet, FTP, `www`, `www-ssl`, API, API-SSL y Winbox siguen deshabilitados (5.1 y 5.2).
- **Alcance de la regla 9.** Permite conexiones nuevas desde USERS y SERVERS **hacia cualquier destino** que salga por las interfaces WAN, no solo hacia las loopbacks ISP (`10.255.255.1/32` y `10.255.255.2/32`). La decisión fue intencional: el alcance de F3 acordado con R1 pide no bloquear conexiones salientes legítimas, y en un escenario real detrás de cada ISP está Internet. R1 lo señaló en su revisión del 23/10 y queda registrado. Restringir los destinos o agregar una denegación general en `forward` solo se hará si R1 lo decide.
- La regla 14 bloquea las conexiones nuevas que entran desde la WAN hacia la red interna. Las respuestas a lo que inician las LAN pasan por la regla 8.
- **Reversión:**
  - solo las denegaciones: `/ip firewall filter remove [find where comment~"^F3 FW deny"]`;
  - todo el firewall de F3: `/ip firewall filter remove [find where comment~"^F3 FW"]` y quitar las listas `FW-*`;
  - último recurso: el backup `EDGE_preFW_F3_20261023.backup`, cuyo restore no se probó.

**TCP-MD5 en eBGP.** Las dos sesiones usan TCP-MD5 con claves por sesión, cargadas por R5 en la consola. En RouterOS 7.16, `/export` no incluye `tcp-md5-key` por defecto, por eso los exports de F3 no la muestran. `/routing bgp connection print` sí la muestra en claro: por eso las sesiones se consultan con `/routing bgp session print` (4.4).

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
| 2026-10-09 | R5 | `982fc39` docs(capturas): organiza evidencias F1 seleccionadas | F1: 26 capturas de R1 seleccionadas y organizadas en `capturas/F1/`; rama `docs/f1-r5-evidencias-operacion` | `git revert 982fc39` |
| 2026-10-09 | R5 | `2d293ca` docs(memoria): documenta despliegue, conectividad, hardening y exports de F1 | F1: memoria 2.1–2.3, 3, 4.1, 5.1, 6.2 y 7.1; misma rama | `git revert 2d293ca` |
| 2026-10-09 | R5 | `cd8c8d5` docs(memoria): integra exports de DIST y checklist F1 tras PR #13 | F1: referencias a los exports de DIST y checklist F1 (10); misma rama | `git revert cd8c8d5` |
| 2026-10-09 | R5 | `f80979d` docs(backlog): marca tareas F1 respaldadas por evidencia | F1: estado de las tareas F1 con evidencia; misma rama | `git revert f80979d` |
| 2026-10-09 | R5 | `341c938` docs(f1): completa interfaces del IPAM y registra cambio de clave de admin | F1: interfaces en la tabla 1.2 y confirmación del cambio de contraseña de `admin`; PR #14 (merge `07e8364`) | `git revert 341c938` |
| 2026-10-10 | R1 | `d937e30` docs(readme): mejora indice y estado del laboratorio | README: índice y estado del laboratorio; PR #15 (merge `c9d48b2`) | `git revert d937e30` |
| 2026-10-13 | R5 | `b80dd30` docs(f0): actualiza estado de aprobacion de F0 tras la devolucion de la catedra | F0 devuelto como aprobado, 100/100; rama `docs/f1-r5-backups-restore` | `git revert b80dd30` |
| 2026-10-13 | R5 | `c108a85` docs(backup): registra backups binarios cifrados de F1 y restore de ISP-1 | F1: inventario privado de los siete `.backup` y restore de ISP-1 informados por R1 (6.2); misma rama | `git revert c108a85` |
| 2026-10-13 | R5 | `1951d06` docs(memoria): registra snapshot F1_FINAL y recuperacion portable del proyecto GNS3 | F1: snapshot final y recuperación portable informados por R1 (2.3); misma rama | `git revert 1951d06` |
| 2026-10-13 | R5 | `e91d251` docs(memoria): actualiza checklist F1 con backups binarios y restore de ISP-1 | F1: checklist (10) alineado con 6.2; misma rama | `git revert e91d251` |
| 2026-10-13 | R5 | `f7f5b79` docs(backlog): marca backups binarios y restore de ISP-1 de F1 | F1: tareas del backlog respaldadas por 6.2; misma rama | `git revert f7f5b79` |
| 2026-10-13 | R5 | `6b27e50` docs(backup): incorpora capturas del restore de ISP-1, corrige fechas y compara con el export | F1: capturas `05_restore/` y comparación con el export (6.2, 7.1); PR #17 (merge `bcb2934`) | `git revert 6b27e50` |
| 2026-10-14 | R1 | `8cb111f` docs(readme): actualiza estado de backups y restore de F1 | README: estado de backups y restore de F1; PR #15 (merge `c9d48b2`) | `git revert 8cb111f` |
| 2026-10-15 | R2 | `2ad2c9b` ops(backup): incorpora exports SSH-MGMT de proveedores | SSH-MGMT: exports de ISP-1/ISP-2 (6.2); PR #18 (merge `b38ee30`) | `git revert 2ad2c9b` |
| 2026-10-15 | R4 | `9337572` ops(backup): incorpora exports SSH-MGMT de distribucion | SSH-MGMT: exports de DIST-1/DIST-2 (6.2); PR #19 (merge `dc57333`) | `git revert 9337572` |
| 2026-10-15 | R3 | `7ba05ad` ops(backup): incorpora exports SSH-MGMT de CORE | SSH-MGMT: exports de CORE-1/CORE-2 (6.2); PR #20 (merge `e5ed9e8`) | `git revert 7ba05ad` |
| 2026-10-15 | R1 | `6bc8c99` ops(backup): incorpora export SSH-MGMT de EDGE | SSH-MGMT: export de EDGE (6.2); PR #21 (merge `102f1a1`) | `git revert 6bc8c99` |
| 2026-10-16 | R5 | `3a2d113` docs(capturas): incorpora evidencias del restore aislado de ISP-1 con SSH-MGMT | SSH-MGMT: siete capturas del restore del 16/10 (7.2); rama `docs/f1-r5-ssh-mgmt-restore` | `git revert 3a2d113` |
| 2026-10-16 | R5 | `0d72b45` docs(readme): registra aprobacion de F1 y estado de SSH-MGMT | Devolución de F1: README sin afirmaciones desactualizadas; misma rama | `git revert 0d72b45` |
| 2026-10-16 | R5 | `bf9225f` docs(memoria): registra devolucion de F1 y documenta SSH-MGMT, backups y restore de ISP-1 | Devolución de F1 y hito SSH-MGMT: memoria 1.2, 2.4, 3, 4.1, 5.2, 6.2, 7.2 y 10; misma rama | `git revert bf9225f` |
| 2026-10-16 | R5 | `1ecd956` docs(backlog): registra SSH-MGMT y observaciones resueltas de la devolucion de F1 | Tareas SSH-MGMT con evidencia y continuidad de backups F2–F4; misma rama | `git revert 1ecd956` |
| 2026-10-17 | R5 | `f6e6d8c` docs(readme): ajusta inventario SSH-MGMT y fecha el estado previo a F2 | README: inventario de la topología SSH-MGMT y estado previo a F2; PR #22 (merge `f922016`) | `git revert f6e6d8c` |
| 2026-10-17 | R1 | `6c385d0` ops(f2): incorpora export saneado de EDGE con OSPF | F2: export de EDGE (6.2); PR #23 (merge `9597b95`) | `git revert 6c385d0` |
| 2026-10-17 | R3 | `7ccac77` ops(f2): incorpora exports OSPF de CORE-1 y CORE-2 | F2: exports de CORE (6.2); PR #24 (merge `188ee20`) | `git revert 7ccac77` |
| 2026-10-17 | R4 | `7dbe505` ops(f2): incorpora exports VRRP y OSPF de DIST-1 y DIST-2 | F2: exports de DIST (6.2); PR #25 (merge `ffdab1c`) | `git revert 7dbe505` |
| 2026-10-19 | R2 | `091b727` ops(f2): incorpora exports de ISP-1 e ISP-2 post-F2 | F2: exports de ISP; el de ISP-1 es el corregido del 19/10 (6.2); PR #26 (merge `07323a5`) | `git revert 091b727` |
| 2026-10-21 | R5 | `0921097` docs(capturas): incorpora las 17 evidencias de F2 revisadas | F2: capturas de R1 en `capturas/F2/`, sin editar (7.3); rama `docs/f2-r5-cierre` | `git revert 0921097` |
| 2026-10-21 | R5 | `be258b6` docs(memoria): documenta VRRP, OSPF, pruebas, respaldos y evidencias de F2 | F2: memoria 3.10, 4.1, 4.2, 4.3, 6.2, 7.3 y 10; misma rama | `git revert be258b6` |
| 2026-10-21 | R5 | `4d1547f` docs(backlog): registra cumplimiento de F2 por rol y sus pendientes | F2: tareas del epic con evidencia y pendientes; misma rama | `git revert 4d1547f` |
| 2026-10-21 | R5 | `7183d19` docs(readme): registra estado de F2 y enlaces a evidencias y exports | F2: estado de la fase y enlaces del README; misma rama | `git revert 7183d19` |

> Integraciones a `main` (merges): PR #1 (R4) `58db8cd`, PR #2 (R3) `5427689`, PR #4 (R5) `e35fdeb`, PR #3 (R2 y consolidación) `e316152`, PR #5 (`.gitignore`) `531056f`, PR #6 (R5) `49510c6`, PR #7 (R5) `07306e5`, PR #8 (R1) `8741527`, PR #9 (R1) `dbbe755`, PR #11 (R1) `170975b`, PR #12 (R2) `83119f5`, PR #10 (R3) `6beba24`, PR #13 (R4) `703c5b9`, PR #14 (R5) `07e8364`, PR #17 (R5) `bcb2934`, PR #15 (R1) `c9d48b2`, PR #18 (R2) `b38ee30`, PR #19 (R4) `dc57333`, PR #20 (R3) `e5ed9e8`, PR #21 (R1) `102f1a1`, PR #22 (R5) `f922016`, PR #23 (R1) `9597b95`, PR #24 (R3) `188ee20`, PR #25 (R4) `ffdab1c` y PR #26 (R2) `07323a5`. La PR #16 se cerró sin merge y la reemplazó la #17, desde la misma rama. Los merges no llevan fila propia; para revertir un PR completo: `git revert -m 1 <merge>`, por ejemplo `git revert -m 1 e316152` (PR #3) o `git revert -m 1 e35fdeb` (PR #4).
>
> `be128f7` fue un merge histórico de `main` hacia la rama de R2 (`docs/f0-r2-proveedores`) para integrar cambios. **No** es el merge final del PR #3: el merge final es `e316152`. Del mismo modo, `77d59a9` lleva `main` a la rama `docs/f1-r5-evidencias-operacion` después de la PR #13. Los commits individuales conservan su autoría y no se reescriben.
>
> Los commits de F1 publican exports, capturas y documentación. La configuración aplicada en los routers no tiene commit propio: se revierte con el comando inverso en la consola o, para volver al estado previo a F1, con el snapshot BASE de GNS3 (2.3), cuyo restore no fue probado. Para recuperar un router, el backup binario cifrado de 6.2 se probó solo en ISP-1.
>
> El commit `2309460` figura en git con autor "Claude"; la PR #13 la abrió R4 (naimguar). Las filas de la rama `docs/f1-r5-evidencias-operacion` corresponden a commits existentes, integrados por la PR #14. Las filas de la rama `docs/f1-r5-backups-restore` corresponden a commits existentes, integrados por la PR #17. Las filas de la rama `docs/f1-r5-ssh-mgmt-restore` corresponden a commits existentes, integrados por la PR #22. Las filas de la rama `docs/f2-r5-cierre` corresponden a commits existentes; su merge queda pendiente de la revisión de R1. En la devolución de F1, la cátedra señaló `2309460` como observación de trazabilidad, no bloqueante: no se reescribe el historial y los commits nuevos se hacen con la identidad Git real de cada integrante.
>
> `1a8d0f2`, `5fff5c9` y `6fb7ee8` solo mantienen este change log y, según 1.4, no llevan fila propia. `1a8d0f2` corrigió hashes de reversión inexistentes en las filas de la PR #14; la cátedra lo destacó en la devolución de F1.

#### Operaciones ejecutadas fuera de Git

Estas operaciones las ejecutó R1 en GNS3 y en las consolas RouterOS; no tienen commit ni hash. R5 las registra según lo informado por R1. Las fechas son las informadas por R1 o las que acreditan los nombres de archivo.

| Fecha | Responsable | Operación | Motivo | Cómo se revierte |
| --- | --- | --- | --- | --- |
| 2026-10-09 | R1 | Snapshot GNS3 `F1_FINAL_2026-10-09` (23:35:42) | Cierre de F1 (2.3) | Eliminar el snapshot en GNS3; no modifica la configuración de los routers |
| 2026-10-10 y 2026-10-13 | R1 | `/system backup save` con `encryption=aes-sha256` en los siete routers: ISP-1 el 10/10 y los otros seis el 13/10 (fechas de los nombres de archivo) | F1: backups binarios de la política 1.4 (6.2) | No modifica la configuración; eliminar los archivos generados |
| 2026-10-10 | R1 | Exportación `topologia_failover_F1.gns3project`, verificación ZIP y recuperación en carpeta aislada; copia de trabajo con `Save project as` | F1: probar la recuperación portable del proyecto (2.3) | Descartar la carpeta aislada y la copia; el proyecto en uso no participó de la prueba |
| 2026-10-13 | R1 | `/system backup load` de `ISP-1_2026-10-10_f1.backup` en `topologia_failover_F1_TRABAJO_BACKUP`, tras cambiar la identidad a `ISP-1_RESTORE_TEST` | F1: probar el restore binario (6.2); satisfactorio | Descartar el proyecto aislado `topologia_failover_F1_TRABAJO_BACKUP` |
| 2026-10-14 | R1 | Red SSH-MGMT en la copia de trabajo GNS3: SW-MGMT, MGMT-CLIENT y ocho enlaces; en los siete routers, VRF `MGMT`, dirección de gestión, tres reglas de firewall, SSH restringido a `172.31.250.10/32` y `strong-crypto=yes`. Pruebas desde `.10` y `.11` | Habilitar SSH restringido a un origen autorizado (2.4, 3.9, 4.1) | En cada router: quitar las reglas de firewall de `MGMT`, la dirección de gestión y la VRF, volver a `/ip ssh set strong-crypto=no` y `/ip service set ssh disabled=yes`; referencia, el export F1 del 09/10. Alternativa: restaurar el backup binario F1 (6.2), probado solo en ISP-1 |
| 2026-10-14 | R1 | `/export` de los siete routers después de SSH-MGMT (encabezados del 15/10 según el reloj de RouterOS) | Exports sanitizados del hito (6.2) | No modifica la configuración |
| 2026-10-15 | R1 | `/system backup save` con `encryption=aes-sha256` en los siete routers, hito `SSH_MGMT` | Segundo juego de backups binarios (6.2) | No modifica la configuración; eliminar los archivos generados |
| 2026-10-16 | R1 | `/system backup load` de `ISP-1_2026-10-15_SSH_MGMT.backup` en `RESTORE_TEST_SSH_MGMT_2026-10-16`; ajuste manual de nombres de interfaces, VRF `MGMT` y direcciones | Probar el restore del juego SSH-MGMT (6.2); exitoso con ajuste manual | Descartar el proyecto aislado `RESTORE_TEST_SSH_MGMT_2026-10-16` |
| 2026-10-16 | R1 | Snapshot GNS3 `PRE_F2_2026-10-16` en `topologia_failover_F1_SSH_MGMT` (13:33:02, hora de GNS3) | Punto de retorno antes de F2 (6.2) | Eliminar el snapshot en GNS3; no modifica la configuración de los routers |
| 2026-10-16 | R1 | VRRP en DIST-1 y DIST-2 (dos grupos, IP virtuales y autenticación `simple`) y OSPF con MD5 en EDGE, CORE-1, CORE-2, DIST-1 y DIST-2. Hora no informada | F2 (3.10) | En cada router, quitar las interfaces VRRP y las IP virtuales y los `interface-template`, el área y la instancia de OSPF; referencia: export SSH-MGMT del 14/10. Alternativa: snapshot `PRE_F2_2026-10-16`, cuyo restore no se probó |
| 2026-10-16 | R1 | Pruebas de failover VRRP: `disable` y `enable` de `vrrp-servers-20` en DIST-2 y `disable` de `vrrp-users-10` en DIST-1 (17:20 a 17:28, hora de las capturas) | Verificar failover y recuperación (4.3) | `/interface vrrp enable` sobre la interfaz deshabilitada; en los exports del 16/10 las cuatro interfaces VRRP están habilitadas |
| 2026-10-16 | R1 | Snapshot GNS3 `F2_FINAL_VRRP_OSPF_2026-10-16` (21:06:24, hora de GNS3) | Cierre de F2 (6.2) | Eliminar el snapshot en GNS3; no modifica la configuración de los routers |
| 2026-10-16 y 2026-10-17 | R1 | `/export` de los siete routers y saneamiento de las claves OSPF (encabezados: routers internos, 16/10 de 23:01 a 23:53; ISP-2, 17/10 02:49) | Exports del hito F2 (6.2) | No modifica la configuración |
| 2026-10-16 | R1 | `/system backup save`, con `encryption=aes-sha256` solicitado, en los siete routers, hito F2 (fecha del nombre de archivo; hora no informada). Preservación de los 14 archivos privados fuera del repositorio con verificación SHA-512 | Juego de respaldos de F2 (6.2) | No modifica la configuración; eliminar los archivos generados |
| 2026-10-17 | R1 | Parada y arranque controlados del proyecto (nodos detenidos a las 00:06, hora de captura) y verificación de conectividad. EDGE volvió a arrancar cerca de las 01:41, con dos mensajes críticos de causa no determinada | Comprobar la recuperación de F2 tras un arranque (4.3) | No aplica |
| 2026-10-19 | R1 | Revisión de interfaces, direcciones y conectividad de ISP-1 y nuevo `/export` (encabezado 15:59:52). No se informaron cambios de configuración | Reemplazar el export F2 de ISP-1 con referencias inválidas (6.2) | No modifica la configuración |

#### Operaciones de F3 ejecutadas fuera de Git

Estas operaciones las ejecutó R5 en su copia GNS3 y en las consolas RouterOS, con autorización de R1 en cada etapa; no tienen commit ni hash. La hora es la de la VM y la de RouterOS (UTC).

| Fecha | Responsable | Operación | Motivo | Cómo se revierte |
| --- | --- | --- | --- | --- |
| 2026-10-19 | R5 | Snapshot GNS3 `PRE_F3_R5_2026-10-18` (16:13:12), con los nodos detenidos | Punto de retorno antes de F3 (6.2) | Eliminar el snapshot en GNS3; no modifica la configuración |
| 2026-10-19 | R5 | Filtros de ruteo `edge-in-isp1`, `edge-in-isp2` y `edge-out-isp` en EDGE; filtros de entrada y salida y address-list de la loopback en ISP-1 e ISP-2; conexiones eBGP con TCP-MD5 en los tres routers (cambios 1 a 10, desde las 17:00) | F3: eBGP con filtros explícitos (3.11) | Quitar las conexiones `/routing bgp connection`, las reglas `/routing filter rule` con comentario `F3` y las address-lists `bgp-isp*-out`. Alternativa: snapshot `PRE_F3_R5_2026-10-18`, cuyo restore no se probó |
| 2026-10-19 | R5 | Cambio de la clave TCP-MD5 coordinado con R1 (19:50 a 20:01) | Alinear la clave con la aprobada en 1.3 (4.4) | Volver a cargar la clave anterior en los dos extremos; el valor no se publica |
| 2026-10-23 | R5 | Cambio 11 en EDGE: address-list `bgp-lan-out` y `output.network=bgp-lan-out` en las dos conexiones (00:12 a 00:23) | F3: anunciar las LAN a los ISP (3.11) | `/routing bgp connection unset [find name~"ebgp-isp"] output.network` y quitar la address-list `bgp-lan-out` |
| 2026-10-23 | R5 | En EDGE: cadena `edge-ospf-out`, `originate-default=if-installed` y `out-filter-chain=edge-ospf-out` en `ospf-v2` (02:42 a 02:52) | F3: default y loopbacks ISP hacia OSPF (3.11) | `/routing ospf instance set ospf-v2 originate-default=never` y `unset … out-filter-chain`, y quitar las reglas de `edge-ospf-out` |
| 2026-10-23 | R5 | Export y backup cifrado de EDGE previos al firewall (20:47 y 21:00) | Respaldo previo al firewall (6.2) | No modifica la configuración |
| 2026-10-23 | R5 | Firewall de EDGE: listas `FW-*` (21:11), 7 aceptaciones (21:22) y 5 denegaciones en Safe Mode (21:29 a 21:31) | F3: firewall de EDGE (5.3) | Ver "Reversión" en 5.3 |
| 2026-10-23 | R5 | Snapshot GNS3 `F3_FW_R5_2026-10-23` (22:35:15), con los nodos detenidos | Punto de retorno antes de las pruebas de caída (6.2) | Eliminar el snapshot en GNS3 |
| 2026-10-23 | R5 | `disable` y `enable` de `ether1` en ISP-1 (23:05 y 23:14) y en ISP-2 (23:20 y 23:29) | Caída y recuperación controlada de cada ISP (4.4) | `/interface enable ether1`; ambas quedaron habilitadas |
| 2026-10-25 | R5 | Snapshot GNS3 `F3_FINAL_R5_2026-10-25` (14:15:58), con los nodos detenidos | Cierre de F3 (6.2) | Eliminar el snapshot en GNS3 |
| 2026-10-25 | R5 | `/export` de los siete routers (14:45 a 14:59) y saneamiento de las 14 claves OSPF | Exports del hito F3 (6.2) | No modifica la configuración |
| 2026-10-25 | R5 | Reinicio de la VM después de que quedara congelada (hacia las 15:27) y nuevo arranque de los nodos | Recuperar el entorno; la configuración persistió (4.4) | No aplica |
| 2026-10-25 | R5 | `/system backup save … encryption=aes-sha256` en los siete routers (16:18 a 16:23); traslado doble y verificación SHA-512 de los 16 archivos privados | Juego de respaldos de F3 (6.2) | No modifica la configuración; eliminar los archivos generados |
| 2026-10-25 | R5 | Verificación funcional posterior a los respaldos (17:00 a 17:06) | Confirmar el estado después del reinicio (4.4) | No aplica |

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

#### Exports SSH-MGMT (`/export`, 14/10)

Después de implementar la red de gestión (2.4), R1 generó un nuevo export de cada router y cada rol publicó los suyos por PR. Se agregaron en `backups/2026-10-14/`, sin reemplazar los exports F1 del 09/10, que se conservan como estado histórico.

| Router | Archivo | Encabezado del export | Publicado por | Commit · PR | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| EDGE | [`EDGE_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/EDGE_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 01:53:09 | R1 | `6bc8c99` · PR #21 (merge `102f1a1`) | `be0af195…139fafff` |
| ISP-1 | [`ISP-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/ISP-1_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:04:02 | R2 | `2ad2c9b` · PR #18 (merge `b38ee30`) | `106bdd4f…cc8b42f6` |
| ISP-2 | [`ISP-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/ISP-2_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:08:53 | R2 | `2ad2c9b` · PR #18 (merge `b38ee30`) | `6a26f6b7…c44893af` |
| CORE-1 | [`CORE-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/CORE-1_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:11:37 | R3 | `7ba05ad` · PR #20 (merge `e5ed9e8`) | `a382cb19…b22ee9f7` |
| CORE-2 | [`CORE-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/CORE-2_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:14:27 | R3 | `7ba05ad` · PR #20 (merge `e5ed9e8`) | `326949dc…236764e3` |
| DIST-1 | [`DIST-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/DIST-1_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:17:50 | R4 | `9337572` · PR #19 (merge `dc57333`) | `e4ca0757…4c229cf9` |
| DIST-2 | [`DIST-2_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/DIST-2_2026-10-14_SSH_MGMT.rsc) | 2026-10-15 02:20:39 | R4 | `9337572` · PR #19 (merge `dc57333`) | `5fce77ec…26ad2431` |

Todos son de RouterOS 7.16. Los nombres usan la fecha del hito (14/10) y los encabezados, la del reloj de RouterOS (15/10 de madrugada). La diferencia es coherente con un reloj en UTC, pero no se verificó en los equipos; los archivos no se modificaron para no alterar su SHA-256. Los SHA-256 abreviados corresponden a los archivos de `main` y coinciden con los informados en cada PR.

**Revisión R5 de los siete exports SSH-MGMT:** frente al export F1 de cada router, la única línea eliminada es `set ssh disabled=yes`; el resto son las altas de 3.9. Direcciones de producción y loopbacks sin cambios, hardening de 5.1 conservado, sin `/ip dhcp-client` y sin usuarios, contraseñas, claves ni salida `show-sensitive`. Las revisiones de R2, R3 y R4 en sus PR llegaron al mismo resultado.

#### Exports F2 (`/export`, 16/10)

R1 generó los exports después de configurar VRRP y OSPF, y los saneó: en los cinco routers internos reemplazó cada `auth-key` de OSPF por `REDACTED_F2_DO_NOT_USE`. Las contraseñas VRRP no figuran en el export. Cada rol revisó y publicó los suyos por PR en `backups/2026-10-16/`, sin reemplazar los juegos anteriores.

| Router | Archivo | Encabezado del export | Bytes | Publicado por | Commit · PR | SHA-256 |
| --- | --- | --- | ---: | --- | --- | --- |
| EDGE | [`EDGE_2026-10-16_f2.rsc`](../backups/2026-10-16/EDGE_2026-10-16_f2.rsc) | 2026-10-16 23:01:31 | 2799 | R1 | `6c385d0` · PR #23 (merge `9597b95`) | `9bdc5df3…695499d5` |
| ISP-1 | [`ISP-1_2026-10-16_f2.rsc`](../backups/2026-10-16/ISP-1_2026-10-16_f2.rsc) | 2026-10-19 15:59:52 | 1870 | R2 | `091b727` · PR #26 (merge `07323a5`) | `2eec5c1b…c3d5e3ad` |
| ISP-2 | [`ISP-2_2026-10-16_f2.rsc`](../backups/2026-10-16/ISP-2_2026-10-16_f2.rsc) | 2026-10-17 02:49:16 | 1870 | R2 | `091b727` · PR #26 (merge `07323a5`) | `084cae03…d0aeea9c` |
| CORE-1 | [`CORE-1_2026-10-16_f2.rsc`](../backups/2026-10-16/CORE-1_2026-10-16_f2.rsc) | 2026-10-16 23:36:01 | 3136 | R3 | `7ccac77` · PR #24 (merge `188ee20`) | `db1424a3…e04339bb` |
| CORE-2 | [`CORE-2_2026-10-16_f2.rsc`](../backups/2026-10-16/CORE-2_2026-10-16_f2.rsc) | 2026-10-16 23:41:40 | 3137 | R3 | `7ccac77` · PR #24 (merge `188ee20`) | `0888d2ff…aa234ad5` |
| DIST-1 | [`DIST-1_2026-10-16_f2.rsc`](../backups/2026-10-16/DIST-1_2026-10-16_f2.rsc) | 2026-10-16 23:48:03 | 3602 | R4 | `7dbe505` · PR #25 (merge `ffdab1c`) | `db0af045…7d806c5d` |
| DIST-2 | [`DIST-2_2026-10-16_f2.rsc`](../backups/2026-10-16/DIST-2_2026-10-16_f2.rsc) | 2026-10-16 23:53:12 | 3602 | R4 | `7dbe505` · PR #25 (merge `ffdab1c`) | `bb96bd4e…85941cb7` |

Todos son de RouterOS 7.16. Los SHA-256 corresponden a los archivos de `main`. Los de EDGE, ISP-2, CORE y DIST coinciden con el inventario de exports saneados que entregó R1.

**Export de ISP-1 (antecedente):** el primer export de F2 de ISP-1 tenía referencias de interfaz inválidas (`*2` y `*3`). Ese export medía 1601 bytes y tenía SHA-256 `062d1842…3484dfd4`; no se publica y queda como antecedente de la incidencia. El 19/10, R1 revisó el router en operación: comprobó sus interfaces, sus direcciones y la conectividad, y generó un export corregido. R2 lo publicó en la PR #26 con el nombre del hito F2. Es el archivo vigente y no se vuelve al anterior. Su contenido es igual al del export SSH-MGMT del 14/10, salvo la línea en blanco final, igual que el de ISP-2.

**Revisión R5 de los siete exports F2:**

- `/system identity` coincide con el nombre del archivo.
- Frente al export SSH-MGMT de cada router, los cinco routers internos solo agregan VRRP, OSPF y las IP virtuales (3.10). En los ISP no hay cambios.
- Direcciones, loopbacks, hardening de 5.1 y gestión de 5.2 se conservan.
- Ninguno contiene usuarios, contraseñas, claves visibles, contenido Base64 ni salida `show-sensitive`.

#### Snapshots GNS3 de F2

R1 creó y confirmó estos snapshots en el proyecto `topologia_failover_F1_SSH_MGMT`. Los dos figuran en la lista de snapshots de la Figura 15.

| Snapshot | Registro en GNS3 | Momento |
| --- | --- | --- |
| `PRE_F2_2026-10-16` | 2026-10-16 13:33:02 | Antes de configurar F2 |
| `F2_FINAL_VRRP_OSPF_2026-10-16` | 2026-10-16 21:06:24 | Cierre de F2 |

La hora de registro la muestra GNS3. Las capturas (por el nombre del archivo) y los exports (por el encabezado de RouterOS) usan otro reloj. En la Figura 17 ese reloj coincide con el de RouterOS. La Figura 15 se tomó a las 00:06:34 del 17/10, 3 horas y 10 segundos después de la hora que GNS3 muestra para `F2_FINAL`. Esa diferencia sugiere relojes en husos distintos, pero no se verificó. Por eso no se afirma que todas las pruebas y los exports sean anteriores o posteriores al snapshot. Las horas se registran con su fuente.

El restore de los snapshots de F2 no se probó.

#### Tipos de respaldo

| Tipo | Contenido | Dónde está | ¿Se publica? |
| --- | --- | --- | --- |
| Export `.rsc` sanitizado | Configuración en texto, sin usuarios ni secretos | `backups/` del repositorio (tabla anterior) | Sí |
| Backup binario `.backup` cifrado | Configuración completa del router, incluidas credenciales | Almacenamiento privado de R1: un juego F1, uno SSH-MGMT y uno F2. El juego F3 está en poder de R5 y su transferencia privada a R1 se coordina aparte (subsecciones siguientes) | No |
| Respaldo portable del proyecto GNS3 (`.gns3project`, snapshots) | Discos QEMU de los siete routers y archivos del proyecto | En poder de R1, fuera del repositorio (2.3) | No |

#### Backups binarios F1 (privados)

R1 generó los siete archivos con `/system backup save`, indicando de forma explícita `encryption=aes-sha256` y una contraseña privada (1.4). Los transfirió en Base64 desde las consolas RouterOS a su almacenamiento privado, los reconstruyó y verificó tamaño y SHA-256 sobre los archivos reconstruidos. R1 informó que repitió la verificación en una auditoría conjunta. R5 documenta lo informado por R1: no tuvo acceso directo a los binarios y no recalculó los SHA-256.

| Router | Archivo | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| ISP-1 | `ISP-1_2026-10-10_f1.backup` | 22701 | `c6ba5ff14b7e878c948632a51e665da2b3de117c04d4ec119d80ae657c8a52ac` |
| ISP-2 | `ISP-2_2026-10-13_f1.backup` | 20205 | `d5f728f3e68153f0ee53d974f38c11f52a0026633c81bc091f0758864816213c` |
| EDGE | `EDGE_2026-10-13_f1.backup` | 20400 | `64a44e330edb0bf528a0443932c7d7c3fa8f13c7083d9a374b4b98e01b5bcf2b` |
| CORE-1 | `CORE-1_2026-10-13_f1.backup` | 20441 | `89ec6b810444a855c025f00c9c8bfd684ed607e5fe23d4dc472a50ed1afcdf62` |
| CORE-2 | `CORE-2_2026-10-13_f1.backup` | 20441 | `8c43e7c2e282ab8f999d8924cef610921a3113cc204044fc1b6b5bb8042b90fb` |
| DIST-1 | `DIST-1_2026-10-13_f1.backup` | 20451 | `983523bb88417052e4b4d5ecfc8d7a80cb98162d3fa5db2e20c7a19b8d794324` |
| DIST-2 | `DIST-2_2026-10-13_f1.backup` | 20451 | `fe4156ea9ba651ab2d823ba4b0f93d117ffc94f0f645ef06c44a1cf6805b467f` |

| Dato | Valor |
| --- | --- |
| Hito | `f1`. La fecha es la del nombre del archivo: ISP-1, 2026-10-10; los otros seis, 2026-10-13 |
| RouterOS | 7.16 |
| Cifrado | `aes-sha256`, solicitado explícitamente al crear cada backup |
| Ejecución | R1 |
| Custodia | Almacenamiento privado local de R1, `GOYS/Respaldos_Privados`, fuera del repositorio. La contraseña se gestiona por un canal privado |
| Permisos | `600` (`-rw-------`) en los siete archivos |
| Comprobación | Tamaño y SHA-256 verificados por R1 después de reconstruir los archivos (informado por R1) |

No se publican los archivos, las contraseñas ni el contenido Base64. Los binarios no se comparan contra los `.rsc` públicos: el formato no es legible sin restaurarlo.

#### Restore binario de ISP-1 (F1, 13/10)

R1 probó la restauración de un solo router, ISP-1, en una copia aislada del proyecto. No se restauraron los otros seis binarios: están generados y verificados, pero no probados.

| Dato | Valor |
| --- | --- |
| Proyecto | `topologia_failover_F1_TRABAJO_BACKUP`, con identificadores distintos de `F1_TRABAJO` (verificado por R1) |
| Archivo | `ISP-1_2026-10-10_f1.backup` (cifrado) |
| RouterOS | 7.16 |
| Ejecución | R1, 2026-10-13 (fecha informada por R1) |
| Procedimiento | Se cambió deliberadamente la identidad a `ISP-1_RESTORE_TEST`; se ejecutó `/system backup load` con el archivo cifrado y la contraseña ingresada de forma privada; RouterOS restauró la configuración y reinició; se inició sesión de nuevo y se verificó el resultado |
| Resultado verificado (informado por R1) | Identidad `ISP-1`; `10.255.0.1/30` en `ether1`; loopback `10.255.255.1/32`; Bandwidth Server deshabilitado; servicios IP deshabilitados; usuario `monitor` presente; grupo `monitor` limitado a `read,ssh`; sin cliente DHCP; acceso administrativo funcional tras la restauración |
| Veredicto | **Restore binario de ISP-1 satisfactorio (RouterOS 7.16)** |
| Evidencia | Dos capturas de la verificación posterior: [`ISP-1_restore_F1_2026-10-13.png`](../capturas/F1/05_restore/ISP-1_restore_F1_2026-10-13.png) (captura 1) e [`ISP-1_restore_usuarios_DHCP_2026-10-13.png`](../capturas/F1/05_restore/ISP-1_restore_usuarios_DHCP_2026-10-13.png) (captura 2). No muestran el `backup load`, el reinicio, el proyecto ni la fecha: eso lo informó R1 |

##### Comparación con el export sanitizado

Se compara lo que muestran las capturas con [`ISP-1_2026-10-09_f1.rsc`](../backups/2026-10-09/ISP-1_2026-10-09_f1.rsc). "Captura" indica que se ve en la imagen y coincide con el export; "R1" indica que lo informó R1 y no hay captura.

| Elemento | Export del 09/10 | Observado tras restaurar | Respaldo |
| --- | --- | --- | --- |
| Identidad | `name=ISP-1` | `ISP-1` | Captura 1 |
| Dirección de enlace | `10.255.0.1/30` en `ether1` (comentario `EDGE`) | Igual | Captura 1 |
| Loopback | `10.255.255.1` (/32) en `lo` | `10.255.255.1/32` en `lo` | Captura 1 |
| Bandwidth Server | `enabled=no` | `enabled: no` | Captura 1 |
| Servicios IP | `telnet`, `ftp`, `www`, `ssh`, `api`, `winbox` y `api-ssl` deshabilitados; `www-ssl` en su valor por defecto (deshabilitado) | Los ocho servicios con la marca `X` (deshabilitado) | Captura 1 |
| Grupo `monitor` | `ssh,read` y el resto negado | Misma política: `ssh,read,!local,…,!rest-api` | Captura 2 |
| Cliente DHCP | Sin `/ip dhcp-client` | `/ip dhcp-client print` sin entradas | Captura 2 |
| Usuario `monitor` | No figura: el export no incluye usuarios | Presente, en el grupo `monitor` | Captura 2 (sin contraparte en el export) |
| Acceso administrativo | No aplica | Las capturas muestran una sesión `admin` ejecutando los comandos. Que el acceso funcione tras el reinicio del restore lo informó R1 | Captura (prompt) y R1 |
| Restauración | No aplica | `backup load` del archivo cifrado, reinicio, identidad previa `ISP-1_RESTORE_TEST` y proyecto aislado | R1; sin captura |

Todos los elementos comparables coinciden con el export. Las capturas no llevan fecha ni muestran el proyecto: que correspondan a la copia aislada, después del restore, se apoya en el informe de R1. Los usuarios y las contraseñas no están en el export, por lo que esa parte de la recuperación solo se acredita por la captura 2 y por R1.

#### Backups binarios SSH-MGMT (privados, 15/10)

Con la red de gestión ya validada, R1 generó un segundo juego de backups binarios de los siete routers con `/system backup save`, `encryption=aes-sha256` y una contraseña privada. Es un juego independiente: no reemplaza a los backups F1, que se conservan. R1 transfirió los archivos en Base64, los reconstruyó en su Mac y verificó cantidad de fragmentos, tamaño, SHA-256 y permisos restringidos. R5 documenta los metadatos informados por R1; no tuvo acceso a los binarios ni recalculó los hashes.

| Router | Archivo | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| EDGE | `EDGE_2026-10-15_SSH_MGMT.backup` | 22904 | `879566e683245af4f4f618cccbd7d984a97b43b7eac3cbbb040ab61abf667885` |
| ISP-1 | `ISP-1_2026-10-15_SSH_MGMT.backup` | 23667 | `778255bab6554952c352e74c128dc2327365c5cd57793a6891935929a9ef51f7` |
| ISP-2 | `ISP-2_2026-10-15_SSH_MGMT.backup` | 22430 | `79d77a91f324eba0bf4f2ce1633b30bf2c1c2457d81d565eedf7ac7297a291a9` |
| CORE-1 | `CORE-1_2026-10-15_SSH_MGMT.backup` | 22947 | `ba4882cdefa42b800c4cf754183f307e08814150f0430e5f189a22be15567dbd` |
| CORE-2 | `CORE-2_2026-10-15_SSH_MGMT.backup` | 22945 | `db4f8071ad4c7e69011bbfa2e624971b915db34a6a9679ce4d1494e41c406201` |
| DIST-1 | `DIST-1_2026-10-15_SSH_MGMT.backup` | 22955 | `edbfc964fb2d82af11ba74c786d2f91e20198c799cd7bb3a5596556d1b291486` |
| DIST-2 | `DIST-2_2026-10-15_SSH_MGMT.backup` | 24192 | `8c1aa08610619e92865f043fae0cc2e8f08f3e2f0f8202c9e830b3f4b23dcfdd` |

| Dato | Valor |
| --- | --- |
| Hito | `SSH_MGMT`, 2026-10-15 (fecha del nombre de archivo) |
| RouterOS | 7.16 |
| Cifrado | `aes-sha256`, solicitado explícitamente |
| Ejecución | R1 |
| Custodia | Carpeta privada de R1 `GOYS-Privado/SSH_MGMT_2026-10-15/`, fuera del repositorio. La contraseña se gestiona por un canal privado |
| Tamaño total | 162.040 bytes |
| Restore probado | Solo ISP-1 (subsección siguiente). Los otros seis no se restauraron |

No se publican los binarios, las contraseñas, los archivos de captura Base64 ni los lotes de transferencia.

#### Restore aislado de ISP-1 (SSH-MGMT, 16/10)

R1 restauró el backup `ISP-1_2026-10-15_SSH_MGMT.backup` en un proyecto GNS3 nuevo, `RESTORE_TEST_SSH_MGMT_2026-10-16`, con un único CHR RouterOS 7.16 sin enlaces con la topología principal (captura 01). La restauración funcionó, pero **no fue automática**: por tratarse de otra máquina virtual, R1 tuvo que corregir a mano las referencias de interfaces, direcciones IP y VRF.

**Procedimiento (ejecutado por R1):**

1. Transfirió el backup al clon por la consola y comprobó que el SHA-512 del archivo coincidía en el ISP-1 original, en su Mac y en el clon: `b67ba46fca073fddb0af322547981aaba2c7e02398068e58ada0ecd1dfc543c0033b10236f235c868dd15b05c1ea80652260a59d0a2be57c2c557a59b257b2b9`.
2. Ejecutó `/system backup load` con la contraseña privada. RouterOS aceptó el archivo, restauró la configuración y reinició.
3. Después del reinicio, el router recuperó la identidad `ISP-1`, los usuarios `admin` y `monitor`, las direcciones y la configuración de servicios. Sin embargo, la dirección de enlace, la de gestión y la VRF `MGMT` apuntaban a interfaces inexistentes (`*2` y `*3`, marcadas como inválidas; captura 02).
4. Las cuatro interfaces Ethernet del clon aparecían como `ether5` a `ether8`, con `default-name` `ether1` a `ether4` (captura 03).
5. R1 renombró las interfaces a `ether1`–`ether4`, volvió a asociar la VRF `MGMT` a `ether2` (captura 04) y reasignó `10.255.0.1/30` a `ether1` y `172.31.250.2/28` a `ether2` (captura 05). La loopback `10.255.255.1/32` no necesitó cambios. El renombrado no tiene captura propia; se deduce de que los comandos siguientes usan `ether1` y `ether2` con resultado válido.
6. Verificó firewall, SSH, usuarios y hardening (capturas 06 y 07).

**Comparación con el export sanitizado** [`ISP-1_2026-10-14_SSH_MGMT.rsc`](../backups/2026-10-14/ISP-1_2026-10-14_SSH_MGMT.rsc), después de los ajustes:

| Elemento | Export del 14/10 | Observado tras el restore y los ajustes | Captura |
| --- | --- | --- | --- |
| Identidad | `ISP-1` | `ISP-1` | 02 |
| Enlace a EDGE | `10.255.0.1/30` en `ether1` | Igual, válida tras reasignarla | 02 (inválida), 05 |
| Loopback | `10.255.255.1` en `lo` | Igual, válida desde el restore | 02, 05 |
| Gestión | `172.31.250.2/28` en `ether2` | Igual, válida tras reasignarla | 02 (inválida), 05 |
| VRF `MGMT` | `interfaces=ether2` | Igual, tras reasociarla | 02 (`*3`), 04 |
| Firewall de `MGMT` | Tres reglas `input` | Las tres, sin marcas de inválida ni deshabilitada | 06 |
| Servicio SSH | `172.31.250.10/32`, VRF `MGMT` | Igual | 02, 07 |
| `strong-crypto` | `yes` | `yes` | 06 |
| Grupo `monitor` | `ssh,read`, resto negado | Igual | 06 |
| Usuario `monitor` | No figura: el export no incluye usuarios | Presente, en el grupo `monitor` | 06 |
| Telnet, FTP, `www`, `www-ssl`, API, API-SSL y Winbox | Deshabilitados | Deshabilitados | 07 |
| Neighbor Discovery | `none` | `none` | 07 |
| MAC Telnet, MAC Winbox y MAC Ping | `none`, `none` y `enabled=no` | Igual | 07 |
| Bandwidth Server | `enabled=no` | `enabled: no` | 07 |
| RoMON | Valor por defecto (no figura) | `enabled: no` | 07 |
| Cliente DHCP | No hay | `/ip dhcp-client print` sin entradas | 07 |

**Veredicto:** restore binario de ISP-1 **exitoso, con ajuste manual de las referencias de interfaces**. Por el aislamiento deliberado del clon no se probó conectividad con otros routers ni se repitieron las pruebas SSH de 4.1. Los otros seis backups SSH-MGMT no se restauraron.

**Lección para el procedimiento de restore:** el binario conserva la configuración, pero en otra máquina virtual las interfaces no quedan asociadas automáticamente. Después de un `backup load` en otra VM hay que revisar `/interface print`, `/ip address print detail` y `/ip vrf print detail` antes de dar el restore por bueno. Este paso tiene que formar parte del procedimiento privado de recuperación, que sigue pendiente.

#### Respaldos privados de F2 (16/10)

Al cerrar F2, R1 generó dos tipos de respaldo privado de cada router: el export original sin sanear y el backup binario. Son 14 archivos en total. Para los binarios usó `/system backup save` y pidió explícitamente el cifrado `aes-sha256` con una contraseña privada. R1 preservó los 14 archivos fuera del repositorio y verificó que el SHA-512 de cada copia coincidiera con el del archivo generado. R5 registra los metadatos informados por R1: no tuvo acceso a los archivos, no recalculó los hashes y no verificó su contenido. Los hashes acreditan la integridad de las copias; no prueban el cifrado ni la posibilidad de restaurarlas.

**Exports originales (privados):**

| Router | Archivo | Bytes | SHA-512 |
| --- | --- | ---: | --- |
| EDGE | `F2_EDGE_20261016_exact.rsc` | 2771 | `70e7f63e30a27094a35f0db8f5d53db03ece51b2bc7c285479af069b20a335d34a431c9159059b018544420c6c76cb175e980c81a521f4d84f10e5164e1d16b5` |
| CORE-1 | `F2_CORE1_20261016.rsc` | 3080 | `04c9a02845c50730a464acd1d6026f087f6867dcf620eb0d66f502581d185e9dadf73d0fb0b485318167099ede890c80a23bfa5189da979ec88b9da1064d52cf` |
| CORE-2 | `F2_CORE2_20261016.rsc` | 3081 | `9fa8f878e996d03ab127c69482463216283595592fd250cd1a347cca6dbdb46d4bff287ad336fd68866c1edca15b2e28eeb742f6967321dd441ecba0f4bc6065` |
| DIST-1 | `F2_DIST1_20261016.rsc` | 3574 | `dcec39452cacd7cdc1c496aceea3ce1c36100fc525123469df765bd40d54b48f2f82b333264f66d019930963ca208f842bf781b674fa521ce94f49343b11d3fb` |
| DIST-2 | `F2_DIST2_20261016.rsc` | 3574 | `67023a15f87ca627b628d31b59ee7f5f8b0e3429cb038417668bedfd21213eca219773bc336edc4100890ce27e8033368b4bee559ce4dc3f400a298b0759b3b2` |
| ISP-1 | `F2_ISP1_20261016.rsc` | 1601 | `a2e47c7a640246445f0a46fb9d380b33bf86022af7056173b830b3b2f4012446d1b045a3979a5c877ed6de1af7d385241e5ffa80a5854ec763581b45ab414143` |
| ISP-2 | `F2_ISP2_20261016.rsc` | 1870 | `89b9b8cbb27d28db4893b267417a03fd5349f059514dd24a448fcd70d21693e411b3fcbb65f5c0d74591d05be876c7283bbfbeb59922f529969af75b6a23d07c` |

El export original de ISP-1 tiene el antecedente de las referencias inválidas `*2` y `*3` descrito en "Exports F2". El vigente es el corregido del 19/10.

**Backups binarios (privados):**

| Router | Archivo | Bytes | SHA-512 |
| --- | --- | ---: | --- |
| EDGE | `F2_EDGE_20261016.backup` | 24769 | `309cafb5b9470231ddcff648733ad1677ec3ce5be6882bd68da65f5eff57546847324566829c33735ce56cb8a0b59a6f823259277969a7eda2db0d3296f0ff91` |
| CORE-1 | `F2_CORE1_20261016.backup` | 25144 | `42ef66beff1b3a7352ae3ff5639d328a7571c3c1b9909fe6ce83bb08f7d0e930c540b31000ddd966aa49bebb5ff17fd934c0f25ae637956d8007cf6d50ba7c93` |
| CORE-2 | `F2_CORE2_20261016.backup` | 25142 | `3264390341e445d5470a3e6ed34738953a87faa13f7c7cbbd807043930e4e9b5efb39f5617c3496d05d177ea5d23587d5ebad7567c3deb7783625732544d9240` |
| DIST-1 | `F2_DIST1_20261016.backup` | 25788 | `43de9029123ca52c256d0789de0089f703204fe50d8fc407df3a4487d347dcff0f5136ccfd0ce5efa91eb93eaca323f8de2df237f3d9031c45e91c9929d2b957` |
| DIST-2 | `F2_DIST2_20261016.backup` | 25789 | `e1e6c008e0e0b7baa471921ce74c65d7d3a61a9c1442195ea315fc4c5526d2a18878c80a0bd11d91dc93e1b19236170db6e140ff926baf866e29a250208bf991` |
| ISP-1 | `F2_ISP1_20261016.backup` | 23667 | `281e099f2d7d887a94db41638fa3f703ffe4d5137e0718dc707209ae99780e88250dc4c92163c4342109669662b63f198b41b8d80c4de3c3108441d932530713` |
| ISP-2 | `F2_ISP2_20261016.backup` | 23666 | `19b0166d9229185f137c4161ce9cced4127f06c3b6cb6af3848c5f552dd307d817d2ec5b65ec4eeb1743983065e63a64d34079e2c895bb23915ac77b63d9753b` |

| Dato | Valor |
| --- | --- |
| Hito | `F2`, 2026-10-16 (fecha del nombre de archivo; R1 no informó la hora) |
| RouterOS | 7.16 |
| Cifrado | `aes-sha256`, solicitado explícitamente al generar cada binario. Los hashes no lo prueban |
| Ejecución y custodia | R1, fuera del repositorio. La contraseña se gestiona por un canal privado |
| Comprobación | SHA-512 de los 14 archivos preservados, verificado por R1 |
| Restore probado | **No.** No se restauró ninguno de los backups de F2 ni el snapshot `F2_FINAL_VRRP_OSPF_2026-10-16` |

No se publican los archivos, las contraseñas ni contenido Base64.

#### Exports F3 (`/export`, 25/10)

R5 generó los exports en su copia GNS3 el 25/10, después del snapshot `F3_FINAL_R5_2026-10-25`, y los sacó de cada router por la consola serie en Base64. Para sanearlos reemplazó los 14 `auth-key` de OSPF por `REDACTED_F3_DO_NOT_USE`: 2 en EDGE, 4 en cada CORE y 2 en cada DIST. RouterOS 7.16 no exporta las claves TCP-MD5, las contraseñas VRRP ni los usuarios. Cada rol revisa y publica los suyos por PR en `backups/2026-10-25/`, sin reemplazar los juegos anteriores.

| Router | Archivo | Encabezado del export | Bytes | Publica | SHA-256 |
| --- | --- | --- | ---: | --- | --- |
| EDGE | [`EDGE_2026-10-25_f3.rsc`](../backups/2026-10-25/EDGE_2026-10-25_f3.rsc) | 2026-10-25 14:50:37 | 7024 | R1 | `86608f29…f7bdeea1` |
| ISP-1 | [`ISP-1_2026-10-25_f3.rsc`](../backups/2026-10-25/ISP-1_2026-10-25_f3.rsc) | 2026-10-25 14:45:21 | 2800 | R2 | `bde76970…0b62354b` |
| ISP-2 | [`ISP-2_2026-10-25_f3.rsc`](../backups/2026-10-25/ISP-2_2026-10-25_f3.rsc) | 2026-10-25 14:48:46 | 2800 | R2 | `e6ed2d4d…71fcc7cd` |
| CORE-1 | [`CORE-1_2026-10-25_f3.rsc`](../backups/2026-10-25/CORE-1_2026-10-25_f3.rsc) | 2026-10-25 14:52:36 | 3136 | R3 | `8b555c83…66a578e1` |
| CORE-2 | [`CORE-2_2026-10-25_f3.rsc`](../backups/2026-10-25/CORE-2_2026-10-25_f3.rsc) | 2026-10-25 14:54:35 | 3137 | R3 | `83ec9c5d…72f93fe4` |
| DIST-1 | [`DIST-1_2026-10-25_f3.rsc`](../backups/2026-10-25/DIST-1_2026-10-25_f3.rsc) | 2026-10-25 14:56:32 | 3602 | R4 | `ed7e9243…6c736ce5` |
| DIST-2 | [`DIST-2_2026-10-25_f3.rsc`](../backups/2026-10-25/DIST-2_2026-10-25_f3.rsc) | 2026-10-25 14:58:38 | 3602 | R4 | `3071a2bd…b1699b01` |

Todos son de RouterOS 7.16 y tienen fin de línea CRLF. El commit y la PR de cada uno se registran en 6.1 cuando se integran a `main`.

**Revisión R5 de los siete exports F3** (auditoría del 26/10):
- `/system identity` coincide con el nombre del archivo.
- **Sin referencias inválidas:** no hay `=*N` ni `*N`, el defecto del primer export de F2 de ISP-1. Todas las interfaces, listas y VRF referenciadas existen.
- **Claves:** las 14 claves OSPF están redactadas. No hay usuarios, contraseñas, claves TCP-MD5 ni VRRP, contenido Base64 ni salida `show-sensitive`.
- **Frente a F2:** CORE-1, CORE-2, DIST-1 y DIST-2 no cambian. ISP-1 e ISP-2 agregan 16 líneas: la address-list de su loopback, la conexión eBGP y 4 reglas de filtro. EDGE agrega las listas `FW-*`, las address-lists, las 12 reglas `F3 FW`, las 2 conexiones eBGP, las 10 reglas de filtro de ruteo y los parámetros `originate-default` y `out-filter-chain` en la instancia OSPF. Ninguno quita configuración de F2.
- **ISP-1 e ISP-2:** sus exports públicos son idénticos a los originales privados, porque no tenían nada que sanear.

#### Snapshots GNS3 de F3

R5 creó estos snapshots en su copia del proyecto, siempre con todos los nodos detenidos. Después volvió a levantar los nodos de a uno. La hora es la que muestra GNS3 en la VM (UTC).

| Snapshot | Registro en GNS3 | Momento | Evidencia |
| --- | --- | --- | --- |
| `PRE_F3_R5_2026-10-18` | 2026-10-19 16:13:12 | Antes de configurar F3, con F2 verificada | F3-1 |
| `F3_FW_R5_2026-10-23` | 2026-10-23 22:35:15 | Con el firewall aplicado, antes de las pruebas de caída de ISP | F3-20 |
| `F3_FINAL_R5_2026-10-25` | 2026-10-25 14:15:58 | Cierre de F3 | F3-27 |

- Los snapshots anteriores (`F1_BASE`, `F1_FINAL`, `SSH_MGMT_7_ROUTEROS_VALIDADO`, `PRE_F2` y `F2_FINAL_VRRP_OSPF`) siguen en la lista y no se restauró ninguno (F3-27).
- En la copia de R5, GNS3 muestra `F2_FINAL_VRRP_OSPF_2026-10-16` a las 00:06:24 del 17/10, 3 horas después de la hora que muestra la Mac de R1 (Figura 15). Esto apoya que la diferencia de 3 horas señalada en "Snapshots GNS3 de F2" es de huso horario.
- El restore de los snapshots de F3 no se probó.

#### Respaldos privados de F3 (23 y 25/10)

R5 generó dos tipos de respaldo privado de cada router: el export original sin sanear (14:45 a 14:59) y el backup binario (16:18 a 16:23). Los binarios se generaron con `/system backup save … encryption=aes-sha256` y una contraseña que R5 tipeó en la consola. Además se sacó del router la copia del export y del backup de EDGE previos al firewall (23/10), pendiente desde la revisión de R1.

**Cómo se trasladaron y verificaron:**
- Se trabajó de a un router por vez: cada router se generaba, se traía y se verificaba antes de pasar al siguiente.
- Cada archivo se trasladó **dos veces por separado** por la consola serie, en Base64, y se decodificó en la PC de R5.
- Los dos traslados dieron el mismo SHA-512 en los 16 archivos.
- **Tamaño:** coincide con el del router; exacto en los `.rsc`, y en los `.backup` coincide además el campo de largo del encabezado.
- **Cifrado:** los 8 `.backup` tienen la cabecera de backup RouterOS cifrado con AES (`EF A8 91 73`). Esto acredita el cifrado, no que el archivo se pueda restaurar.

| Router | Archivo | Bytes | SHA-512 |
| --- | --- | ---: | --- |
| EDGE | `F3_EDGE_20261025.rsc` | 6996 | `a5cc2d587fa54cbdaf0645ee947acdf125c61812aae43091617eb37f84add5d1d1bb2dff6ee7973c08a5d7d3f858f667a93bed74126205b3607cd6eac1cc399c` |
| EDGE | `F3_EDGE_20261025.backup` | 29651 | `2b94bf2dbb079ba45b6fa2e7457ff9cacf1803b606bd17b386856c1869e6397a01d01383e3a56d96b7be8401b34aee8c068c9f21a6dcff8cca36d53eb3e3a052` |
| ISP-1 | `F3_ISP1_20261025.rsc` | 2800 | `b4c785edadd6d33281fcef6a888b86dbec73bc73402a22d0307308af043014d33f618ff8d87327542f78e3d23d2a222b09779726b26ace3852711acb3032cdd6` |
| ISP-1 | `F3_ISP1_20261025.backup` | 24599 | `214b5709fac6fa47561c62be71ce4e592603bfda3516efb3703822e8077c1c7c5d883216fcd63c2429f846045efe0e623fbbe6cf4bf0e718c6cc462a6e73c879` |
| ISP-2 | `F3_ISP2_20261025.rsc` | 2800 | `b222a3f37b0dfd722b034bcdd0fe74866cede191a5eedfc7cc48bf06e10a7571213d1f22b36fe819a71d3fada1747d581a4c0bd5651f3e84a48a8d48efd930bc` |
| ISP-2 | `F3_ISP2_20261025.backup` | 24598 | `6af969419bf8b1bf081c4f093f52992796151ff0499b66557be1dfee820ef970bd9285814c92251941b8f22cb91ddfdda60471129818527d38fa7fbe8f86577d` |
| CORE-1 | `F3_CORE1_20261025.rsc` | 3080 | `d8fd419019a6ec5a0b6e28ddb4fcb9d78c7f1f2cffa92177070909ce8737d343bf404bf8b5711d698459753ba125af102141cecd52dfff978325bbd5b2ed5484` |
| CORE-1 | `F3_CORE1_20261025.backup` | 25124 | `9fea253ab3a05df5f4cb443a007050f76e29a6aa797bc082dba1add619c7983575599c148ba43d4ae7d56d67981620054e356b1d2b5846c363b092debd981326` |
| CORE-2 | `F3_CORE2_20261025.rsc` | 3081 | `b6e4153aa0b22116d5251aa18991d4c2e958bee16826c03f0aa40bdbea3f12fc11b7f8b4087fc371cdec153cca0a51e44a76ff7f4dade4ce6c806bdb226a3e9a` |
| CORE-2 | `F3_CORE2_20261025.backup` | 25122 | `79b88a342fee998e73b1a95e01fb88ddfa8885ca0926cea522cd56aaaad5c97736983aa4b067ad4f6f9600b3fc628abbf445079ba76a999d4f911d49108339ad` |
| DIST-1 | `F3_DIST1_20261025.rsc` | 3574 | `bb1ac304733c6331a378eb9d1532c79ccbb1828fb6fe7d90a18cbace09a6cfdd3782397b7d38b35d164342513ac0f42e38a41877c1a95df96c4d6a6bd3c3b20f` |
| DIST-1 | `F3_DIST1_20261025.backup` | 25768 | `a418a13e5788a95e5d59e55671437e226cb88c66afcc8e34e5941cd3761c94ec13a1fe0ffe3d62f44bc196285248a59c5e67dc722172e22af925c56587081180` |
| DIST-2 | `F3_DIST2_20261025.rsc` | 3574 | `e11dcbd54608fb0e213326f784fec7a3c25f6ca7b807d037d575fb758dcd50fb3c30d7acac094ee46cd9a37bbdcc0c97d65f4c3af6ab1b70629a0cd152f9edf7` |
| DIST-2 | `F3_DIST2_20261025.backup` | 25789 | `dbfddb75dac4db16e2ba621e36499c104962ffad6f2b945ec2f016916904f2e1e9f667c55ef796fd0ec3c024de206f81603308f7576b61ab9f3ee499deb0ea88` |
| EDGE (antes del firewall) | `EDGE_preFW_F3_20261023.rsc` | 4757 | `1cc1e54fe239755ceac98044947534cc5ed2ffc7bfe382c5f11bdfe0d619a053cb68327b27422be84a1aeecb6d7a68a7ee1d19ca5b88456ffb18b37d2cc0b343` |
| EDGE (antes del firewall) | `EDGE_preFW_F3_20261023.backup` | 26807 | `0f17f128c0443ecd15afbeeb89fa9f28b00e1540f47cc8b8c8e31a7a69c3fc16064c15b9b0e2e1edc48053835bf72ec6fc5ec3cd3ee97ec0e53367a29f7d9906` |

| Dato | Valor |
| --- | --- |
| Hito | `F3`: exports del 25/10 de 14:45 a 14:59 y backups de 16:18 a 16:23 (hora de RouterOS, UTC). Pre-firewall de EDGE: 23/10, 20:47 y 21:00 |
| RouterOS | 7.16 |
| Cifrado | `aes-sha256`, acreditado por la cabecera de los 8 `.backup` |
| Custodia | Dos juegos independientes en el almacenamiento local de R5, fuera del repositorio, verificados con `sha512sum -c` (16/16 en cada uno). Los originales siguen además en cada router. La transferencia privada a R1 se coordina aparte |
| Restore probado | **No.** No se restauró ningún backup de F3 ni el snapshot `F3_FINAL_R5_2026-10-25` |

Los exports originales de EDGE, CORE y DIST contienen las claves OSPF en claro y no se publican. Tampoco se publican los binarios, la contraseña de los backups ni contenido Base64.

#### Política interna de backup: procedimientos adicionales

Estado de los procedimientos de 1.4:

| Procedimiento (política 1.4) | Estado |
| --- | --- |
| Snapshot BASE | Registrado en GNS3 (2.3). No es un backup de RouterOS y no se probó su restore |
| Snapshot `F1_FINAL_2026-10-09` y copia portable del proyecto GNS3 | Realizados por R1. Recuperación del proyecto validada en una copia aislada (2.3). El restore de snapshots individuales de GNS3 no se probó |
| Export `base` de cada router antes de configurar | No se generó |
| Backup binario `.backup` cifrado, fuera del repositorio | **Realizado** para los siete routers en cuatro hitos: F1 (10 y 13/10), SSH-MGMT (15/10) y F2 (16/10) por R1, y F3 (25/10) por R5; archivos verificados por quien los generó |
| Registro de localizador privado, checksum y resultado de cada binario | **Registrado** arriba para los tres juegos: tamaño, hash, RouterOS 7.16 y fecha. En F1 y SSH-MGMT también el localizador privado; en F2, R1 informó la custodia fuera del repositorio sin indicar un localizador |
| Restore probado en un router con la misma versión de RouterOS | **Realizado en ISP-1** en los juegos F1 y SSH-MGMT, con capturas y comparación contra el export (arriba). F1: satisfactorio. SSH-MGMT: exitoso con ajuste manual de interfaces, direcciones y VRF. En cada uno de esos juegos, seis binarios sin restaurar. **F2 y F3: ningún backup restaurado** |
| Procedimiento privado para reinyectar claves y reprovisionar usuarios | **Pendiente**: los dos restores de ISP-1 recuperaron el acceso administrativo, pero el procedimiento escrito no existe. Debe incluir la revisión de interfaces tras un restore en otra VM |

Los `.rsc` publicados están sanitizados: no incluyen usuarios ni contraseñas, de modo que por sí solos no permiten recuperar las credenciales de gestión. En ISP-1, el binario cifrado sí las recuperó (acceso administrativo funcional tras el restore, informado por R1). El procedimiento privado por escrito sigue pendiente. En el repositorio no se publican binarios, contraseñas ni localizadores secretos.

#### Respaldos por hito: estado y planificación

En la devolución de F1, la cátedra pidió sostener un juego de backups independiente por hito en F2, F3 y los drills de F4. Cada juego se suma a los anteriores sin sobrescribirlos y sigue la política 1.4: export `.rsc` sanitizado publicado por PR y backup binario cifrado fuera del repositorio. R5 coordina cada hito y verifica los metadatos de los siete routers antes de darlo por cerrado.

| Hito | Exports en `backups/` | Binarios cifrados | Restore probado | Estado |
| --- | --- | --- | --- | --- |
| F1 | `2026-10-09/` (y EDGE `2026-10-08/`) | 7, del 10 y 13/10 | ISP-1, 13/10 | Realizado |
| SSH-MGMT | `2026-10-14/` | 7, del 15/10 | ISP-1, 16/10, con ajuste manual | Realizado |
| F2 (VRRP y OSPF) | `2026-10-16/` | 7, del 16/10 | No | Realizado, sin restore probado |
| F3 (BGP y firewall) | `2026-10-25/` (pendiente de las PR de R1 a R4) | 7, del 25/10, más el pre-firewall de EDGE del 23/10 | No | Realizado, sin restore probado; exports auditados y pendientes de publicación |
| F4 (5 drills) | — | — | — | Planificado: `pre-drillN` y `post-drillN` en cada drill |

Los hitos planificados se marcarán como realizados solo cuando existan los archivos y su registro en 6.1 y en esta sección.

### 6.3 Monitoreo

Pendiente R5.

---

## 7. Capturas

### 7.1 F1

R1 tomó las capturas en su instancia GNS3 y las entregó a R5 sin editar. R5 seleccionó 26 de las 27 recibidas y las organizó en [`capturas/F1/`](../capturas/F1/). Las copias del repositorio son idénticas a las del paquete recibido (verificado por SHA-256). Las capturas de consola no muestran fecha; solo se indica fecha cuando la imagen o su origen la acreditan. Las dos de `05_restore/` las entregó R1 después (verificación de ISP-1 tras el restore): son fotografías de pantalla de la consola GNS3 tomadas desde un celular, incluyen la barra de estado del teléfono y se convirtieron a PNG sin otra edición. No exponen contraseñas ni secretos.

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
| `05_restore/ISP-1_restore_F1_2026-10-13.png` | ISP-1 tras el restore: identidad, direcciones, loopback, Bandwidth Server y servicios IP | 6.2 |
| `05_restore/ISP-1_restore_usuarios_DHCP_2026-10-13.png` | ISP-1 tras el restore: usuario y grupo `monitor`, y ausencia de cliente DHCP | 6.2 |

**Excluida:** `EDGE_administracion_MAC.png`, del paquete de R1. Es un estado intermedio: muestra SSH todavía habilitado y la administración MAC antes y después del cambio. El estado final está cubierto por `EDGE_neighbor_discovery_deshabilitado.png` y por la captura final del 09/10. Queda fuera del repositorio, en el paquete original.

**Observación:** la captura final de DIST-1 conserva arriba el comando `/export file=DIST-2_F1_2026-10-09` (ver 6.2). No altera lo que la captura demuestra, pero conviene repetirla sin ese comando antes de la entrega definitiva.

### 7.2 SSH-MGMT y restore aislado de ISP-1 (16/10)

R1 tomó estas siete capturas en la prueba de restore de 6.2 y R5 las incorporó sin editar en [`capturas/F1/06_ssh_mgmt_restore/`](../capturas/F1/06_ssh_mgmt_restore/); las copias del repositorio son idénticas a las recibidas (verificado por SHA-256). Son capturas de pantalla de la Mac de R1. Las de consola no muestran fecha: la fecha surge del nombre del proyecto en la captura 01 y de lo informado por R1. Revisamos las siete: son legibles y no exponen contraseñas, claves ni contenido Base64. No hay capturas de las pruebas SSH de 4.1 sobre la topología principal.

| Archivo (`capturas/F1/06_ssh_mgmt_restore/…`) | Qué demuestra | Sección |
| --- | --- | --- |
| `01_proyecto_restore_aislado.png` | Proyecto `RESTORE_TEST_SSH_MGMT_2026-10-16` con un único CHR `ISP-1`, sin enlaces y detenido antes de la prueba | 6.2 |
| `02_restore_referencias_invalidas.png` | Tras el restore: identidad `ISP-1`, direcciones de enlace y gestión inválidas (`*2`, `*3`), VRF `MGMT` en `*3` y servicio SSH recuperado | 6.2 |
| `03_interfaces_clon_mapeo.png` | Interfaces del clon con nombres `ether5` a `ether8` y `default-name` `ether1` a `ether4` | 6.2 |
| `04_vrf_mgmt_recuperada.png` | VRF `MGMT` reasociada a `ether2` | 6.2 |
| `05_ipam_corregido.png` | Direcciones reasignadas a `ether1` y `ether2`, y loopback válida | 6.2 |
| `06_firewall_ssh_monitor_restaurado.png` | Tres reglas de firewall de `MGMT`, `strong-crypto=yes`, grupo y usuario `monitor` | 5.2, 6.2 |
| `07_hardening_restore.png` | Servicios IP, SSH solo desde `.10` en `MGMT`, Neighbor Discovery, administración MAC, Bandwidth Server, RoMON y ausencia de cliente DHCP | 5.2, 6.2 |

### 7.3 F2: VRRP y OSPF (16 y 17/10)

R1 tomó estas 17 capturas en su Mac durante las pruebas de F2 y las entregó a R5 sin editar. R5 las incorporó en [`capturas/F2/`](../capturas/F2/) con sus nombres originales y sin modificaciones. Las copias del repositorio son idénticas a las del paquete recibido: los SHA-256 de la tabla coinciden con el manifiesto entregado por R1.

Las revisamos una por una. Son legibles y no muestran contraseñas, claves VRRP, OSPF ni BGP, ni contenido Base64. R1 entregó aparte las capturas que mostraban claves y no se incorporaron. En las barras de título se ven el usuario `agustin` (Figuras 4, 5 y 11 a 16) y el nombre del equipo de R1 (Figura 15); R1 autorizó publicarlas así. Los títulos `telnet localhost <puerto>` son la consola de GNS3 (5.1).

La hora es la del nombre del archivo original. En la Figura 17 coincide con el reloj de RouterOS (6.2, "Snapshots GNS3 de F2").

| Figura | Archivo (`capturas/F2/…`) | Hora | Qué muestra | Sección | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| Figura 1 | `01_VRRP/01_VRRP_DIST1.png` | 16/10 17:27 | Roles VRRP en DIST-1 y deshabilitación de `vrrp-users-10` | 4.3 | `758274e477b71abe3c2fc0ac5fdbe3a093f36d312eef10438e27d77033fe7137` |
| Figura 2 | `01_VRRP/02_VRRP_DIST2.png` | 17/10 00:18 | DIST-2: MASTER en SERVERS y BACKUP en USERS | 4.3 | `56befa2da034a89ac7afffa01dbfe1aa05dd64cf1e757fcba9dee1cc27594c77` |
| Figura 3 | `01_VRRP/03_VRRP_RECUPERACION_SERVERS.png` | 16/10 17:23 | DIST-2: deshabilitación y rehabilitación de SERVERS; vuelve de BACKUP a MASTER | 4.3 | `0723c9778883f769c18c7c74691c1003aa6671d399f198efed9873fc681a62f8` |
| Figura 4 | `01_VRRP/04_VRRP_FAILOVER_USERS_PING.png` | 16/10 17:28 | PC-USER: dos pings 5/5 al gateway virtual `192.168.10.1`; no muestra el estado VRRP | 4.1, 4.3 | `c681d509631f601d84be7f827d8f45e1f532386f318411c54801a7065193ff30` |
| Figura 5 | `01_VRRP/05_VRRP_FAILOVER_SERVERS_PING.png` | 16/10 17:20 | SRV: configuración y dos pings 5/5 al gateway virtual `192.168.20.1`; no muestra el estado VRRP | 4.1, 4.3 | `166fe1b299d847e82591fc45301c14c23baf41112324b95b7a0b8813f7e4c339` |
| Figura 6 | `02_OSPF/06_OSPF_EDGE_VECINOS.png` | 17/10 00:10 | EDGE: dos vecinos OSPF en `Full` (CORE-1 y CORE-2) | 4.3 | `7604c0faf1c77103a7b01e6fe8b8abdb26e5aa251de16d5254b5e6a4fae0b470` |
| Figura 7 | `02_OSPF/07_OSPF_CORE1_VECINOS.png` | 17/10 00:12 | CORE-1: cuatro vecinos OSPF en `Full` | 4.3 | `86db5ab6227324b7d9d3492bda4a72c5c1057b9d484df24f8ee9b021fe7cc5af` |
| Figura 8 | `02_OSPF/08_OSPF_CORE2_VECINOS.png` | 17/10 00:13 | CORE-2: cuatro vecinos OSPF en `Full` | 4.3 | `1df72a8c060947cf9b7ffe9f92172648ffee6074b1276a1322b0d4405e922dc5` |
| Figura 9 | `02_OSPF/09_OSPF_RUTAS_LAN_ECMP.png` | 17/10 00:15 | EDGE: rutas OSPF a las dos LAN con dos nexthops ECMP | 4.3 | `9bacf8d7d1f2e98caf1b44fb69854af3409e158d35c3aa44aa74422eda16d233` |
| Figura 10 | `02_OSPF/10_OSPF_LOOPBACKS_DIST.png` | 16/10 22:35 | EDGE: rutas a las loopbacks de CORE y DIST; las de DIST, por ECMP | 4.3 | `5f8e8ca5f68a67347e12cea26a218dc661c9798ce9a283b7bf33031e2ade11ff` |
| Figura 11 | `03_Conectividad/11_PING_USERS_SERVERS.png` | 16/10 22:51 | PC-USER → SRV: 5/5 | 4.1 | `711a227421fc504d9e45d8e04c59073bc45cb5195433f27ba16a289008600685` |
| Figura 12 | `03_Conectividad/12_PING_SERVERS_USERS.png` | 16/10 22:52 | SRV → PC-USER: 5/5 | 4.1 | `8d7c83273fce67ab3405b9b0eb3e0c928fa4948c5b615de84bc112bc5c61f7aa` |
| Figura 13 | `03_Conectividad/13_PING_USERS_EDGE.png` | 16/10 22:55 | PC-USER → loopback de EDGE `10.255.255.3`: 5/5 | 4.1 | `db89448a7de9b4688e888a928198b3a1cafea5564675d080f213cd4c9fe56565` |
| Figura 14 | `03_Conectividad/14_PING_SERVERS_EDGE.png` | 16/10 22:57 | SRV → loopback de EDGE `10.255.255.3`: 5/5 | 4.1 | `4b7cf4d0c5b7a69049635fc2790275d23de13364e4a39175dc9143505f09a5a6` |
| Figura 15 | `04_Respaldo/15_SNAPSHOT_FINAL.png` | 17/10 00:06 | GNS3: snapshots `PRE_F2_2026-10-16` y `F2_FINAL_VRRP_OSPF_2026-10-16`; nodos detenidos | 4.3, 6.2 | `42347d2012f3c0d70032e191595d19e05e966cbf809836b442b28d1ab3c01bd0` |
| Figura 16 | `05_Recuperacion/16_PING_POST_ARRANQUE.png` | 17/10 01:44 | PC-USER → SRV después del arranque: 5/5 | 4.1, 4.3 | `4242c920927eb4bcdae999e49913a2dc25a726c78ee4bf891e4b2ed1f2d900d3` |
| Figura 17 | `06_Estabilidad/17_ESTABILIDAD_EDGE.png` | 17/10 02:03 | EDGE: uptime de 22m16s, recursos y dos mensajes críticos del arranque | 4.3 | `7e2eef4562a0bd59efbcb3a2837232467c96c668afb6fd0248693ced127f6f71` |

### 7.4 F3: BGP, firewall y caída de ISP (19 a 25/10)

R5 generó estas evidencias en su copia GNS3. 26 son salidas de consola en texto y 3 son capturas de la lista de snapshots de GNS3. Están en [`capturas/F3/`](../capturas/F3/) con sus nombres originales y sin modificaciones: los SHA-256 de la tabla son los de las copias privadas de R5.

Antes de publicarlas se revisaron una por una:
- no muestran claves TCP-MD5, OSPF ni VRRP, contraseñas ni contenido Base64;
- donde un comando mostraba una clave, el valor ya figuraba reemplazado por `<REDACTADO>` en la salida guardada;
- en el resto de los casos, las sesiones BGP se consultaron con comandos que no muestran claves.

Algunas salidas conservan rastros de la herramienta que trasladó el texto desde la VM: la verificación md5 de los scripts antes de ejecutarlos (checkpoint de F3, 4.4) y, en F3-22, errores de un script auxiliar que no llegó a ejecutarse en los routers. En F3-5 y F3-29 aparecen intentos de login fallidos: son consultas de solo lectura que llegaron a consolas sin sesión iniciada y no tuvieron efecto (4.4).

La hora es la de la VM y la de RouterOS, ambas en UTC.

| Evidencia | Archivo (`capturas/F3/…`) | Hora (VM, UTC) | Qué muestra | Sección | SHA-256 |
| --- | --- | --- | --- | --- | --- |
| F3-1 | `01_Checkpoint0/02_snapshot_PRE_F3_R5_creado.jpg` | 19/10 16:13 | GNS3: lista de snapshots con `PRE_F3_R5_2026-10-18` recién creado | 4.4, 6.2 | `bc7456f64a828700ef3e5e849906961b42bcb3b902834bae29f55cb77d0c4433` |
| F3-2 | `01_Checkpoint0/04_ospf_vrrp_rutas_EDGE_CORE_DIST_1636.txt` | 19/10 16:36 | Checkpoint 0: vecinos OSPF, roles VRRP y rutas de EDGE, CORE y DIST antes de F3 | 4.4 | `8f19312aae9a5138f0fe366f0cb7a67ec49be195b872e8fb740db1d027e95edb` |
| F3-3 | `02_eBGP/F3_06_eBGP_ISP1_established_y_F2_1716.txt` | 19/10 17:16 | Sesión eBGP EDGE–ISP-1 en `established`, rutas recibidas y F2 sin cambios | 4.4 | `dc9756e11d1a4b8e535a6865ac3345eb6fafa13c2c353b57e203ecad892fccde` |
| F3-4 | `02_eBGP/F3_11_eBGP_ISP2_established_y_F2.txt` | 19/10 | Sesión eBGP EDGE–ISP-2 en `established`, rutas recibidas y F2 sin cambios | 4.4 | `1f63e79bcf78f4b903ddd54c2846d63a60e56057312fc48856dfc5bece02615b` |
| F3-5 | `02_eBGP/F3_14_verificacion_cambio_clave_2002.txt` | 19/10 20:02 | Sesiones después del cambio de clave TCP-MD5 y log de cierre y restablecimiento | 4.4 | `db584cc59c6e4a907a3e40f5cb7afb3d1bd5ac9cc5c7895cf5c6b8246b34ed55` |
| F3-6 | `03_Anuncio_LAN/F3_19_cambio11a_EDGE_anuncia_LAN_a_ISP1_0012.txt` | 23/10 00:12 | Cambio 11a: EDGE anuncia las LAN a ISP-1; ISP-1 recibe exactamente las dos | 3.11, 4.4 | `8c89bb0f1edbfeffda2d311ae086d96dbe46baa241c9fee0d917b951af58b5af` |
| F3-7 | `03_Anuncio_LAN/F3_20_cambio11b_EDGE_anuncia_LAN_a_ISP2_0023.txt` | 23/10 00:23 | Cambio 11b: lo mismo hacia ISP-2; F2 sin cambios | 3.11, 4.4 | `5da398093514c391575c5477500849d9f92a2082519d0704262421dfb74965ad` |
| F3-8 | `04_OSPF_default/F3_22_paso1_filtro_edge-ospf-out_0242.txt` | 23/10 02:42 | Cadena `edge-ospf-out` | 3.11 | `8bc2654ecdb2bc952d203d844056f0886836b65ab8e305732240c9f4562dcad5` |
| F3-9 | `04_OSPF_default/F3_23_paso2_originate-default_if-installed_0244.txt` | 23/10 02:44 | `originate-default=if-installed` en la instancia OSPF de EDGE | 3.11 | `189946416788c46e6941bf3b0796c9f8d094d05f5aeef40375f237d07eba3ecd` |
| F3-10 | `04_OSPF_default/F3_24_paso3_out-filter-chain_0252.txt` | 23/10 02:52 | `out-filter-chain` asociado; EDGE origina 3 LSA externos | 3.11, 4.4 | `6827171a503b59682bb06ee5e1674973b955705e6b3c7b13321d974ee9b7d76c` |
| F3-11 | `04_OSPF_default/F3_24b_paso3_rutas_CORE_DIST_0255.txt` | 23/10 02:55 | CORE y DIST aprenden el default y las loopbacks ISP | 4.4 | `c245a06180cefeb45257b430462ff26dbd4f6f949834937651ffcaf9f81e6b91` |
| F3-12 | `04_OSPF_default/F3_25_verificacion_final_OSPF_pings_traceroutes_0258.txt` | 23/10 02:58 | Verificación final de OSPF, pings y traceroutes de PC-USER y SRV a las loopbacks ISP | 4.1, 4.4 | `7e16a6e96ce460ba6fd6602094aa7147fb515601dbfed9ec57d2fa455f3533b0` |
| F3-13 | `05_Firewall/F3_29_paso1_listas_FW_2110.txt` | 23/10 21:10 | Listas de interfaces y address-lists `FW-*` | 5.3 | `92fa759d1ff0942431c739f25242bea83cdb82735aaf41a596346b9ef455d49a` |
| F3-14 | `05_Firewall/F3_30_paso2_aceptaciones_2122.txt` | 23/10 21:22 | Siete reglas de aceptación y sus contadores | 5.3 | `a8a2a915a1c39173781d1cf776e1b1afbf7c4d71f892e6120253c826237db7e8` |
| F3-15 | `05_Firewall/F3_31_paso3_denegaciones_safe_mode_2129.txt` | 23/10 21:29 | Cinco denegaciones aplicadas en Safe Mode | 4.4, 5.3 | `272a5d48ba9c139fa82afd680fe736de22818fac886144683b6251acb1f3d09e` |
| F3-16 | `05_Firewall/F3_32_paso3_verificacion_post_deny_2132.txt` | 23/10 21:32 | Pings, BGP, OSPF, VRRP y contadores con el firewall completo | 4.1, 4.4 | `21817933e8a9f16d25e91d5fa258bf53f2d2d7a40ccdd67dbc6611506ed4cdd0` |
| F3-17 | `05_Firewall/F3_33_prueba1_SSH_autorizado_MGMT-CLIENT_2206.txt` | 23/10 22:06 | SSH autorizado desde MGMT-CLIENT: EDGE pide contraseña; se aborta sin ingresarla | 4.4 | `962441342675960c472b659284181d6d56bf32d11d704fb0fd6b97d8760c031d` |
| F3-18 | `05_Firewall/F3_34_prueba2_SSH_no_autorizado_CORE-1_2207.txt` | 23/10 22:07 | SSH desde CORE-1 por la VRF `MGMT`: sin respuesta | 4.4 | `1de747b4284997d5ccc58a30eaccbbcf6288d24d88569ed3864144893f2bea98` |
| F3-19 | `05_Firewall/F3_35_prueba3_SSH_desde_ISP1_bloqueado_2208.txt` | 23/10 22:08 | SSH desde ISP-1 al enlace WAN de EDGE: sin respuesta | 4.4 | `3ab9703330a1470b3701090ddad42f59e9f6b802cb15cf166979bc5632d59b08` |
| F3-20 | `06_Failover_ISP/F3_36_snapshot_F3_FW_R5_2235.jpg` | 23/10 22:35 | GNS3: snapshot `F3_FW_R5_2026-10-23` | 4.4, 6.2 | `1e9cd06e63d24be4c4f52aeaa3abd02771d66139ffbcc6eecc262dc252ff4f28` |
| F3-21 | `06_Failover_ISP/F3_37_base_post_snapshot_2257.txt` | 23/10 22:57 | Línea base antes de las pruebas de caída | 4.4 | `ad33587112bc8f9f7abe7414fb166c52c71516d5f54b3bf1de7a5460e3c779b5` |
| F3-22 | `06_Failover_ISP/F3_38_ISP1_caido_2305.txt` | 23/10 23:05 | ISP-1 caído: EDGE, rutas y conectividad | 4.4 | `7515bb41bd7f4ae4ef057b5646fbc77fc4f7eaa0cdc176136eee49224168aa59` |
| F3-23 | `06_Failover_ISP/F3_38b_ISP1_caido_CORE_DIST_2312.txt` | 23/10 23:12 | ISP-1 caído: CORE y DIST | 4.4 | `b1479ec329baee7a9a024ff1556eaa14e199f2bb3188201ab6ffadca3d46cf79` |
| F3-24 | `06_Failover_ISP/F3_39_ISP1_recuperado_2314.txt` | 23/10 23:14 | ISP-1 recuperado | 4.4 | `f20932dfbf9e63014df1ce38fe5429d2c10460cc20316890b5957789a18db6e6` |
| F3-25 | `06_Failover_ISP/F3_40_ISP2_caido_2320.txt` | 23/10 23:20 | ISP-2 caído | 4.4 | `2d569b7780a3ff8c5a436b0aa39065b87e8e5c1f547b91b0c9f54199c0aff0cb` |
| F3-26 | `06_Failover_ISP/F3_41_ISP2_recuperado_y_estado_final_2329.txt` | 23/10 23:29 | ISP-2 recuperado y estado final | 4.4 | `773f05688e8e81df94efbacceddc158a7b19f7cf6b37045ff1de90c484d4ae50` |
| F3-27 | `07_Cierre/F3_42_snapshot_F3_FINAL_R5_1415.jpg` | 25/10 14:15 | GNS3: los ocho snapshots, con `F3_FINAL_R5_2026-10-25` al final | 4.4, 6.2 | `8b53852347c56bf61924b79fb30e24b3987efb0226886ed7bf02c02070b287b2` |
| F3-28 | `07_Cierre/F3_44_listado_exports_y_backups_routers_1633.txt` | 25/10 16:33 | Exports y backups de F3 en el almacenamiento de cada router | 6.2 | `f2cfbfa37f1d6a75d5e83b5ea7d8c1893e81af0929ea76990f828846e4cc1412` |
| F3-29 | `07_Cierre/F3_45_verificacion_post_respaldos_1700.txt` | 25/10 17:00 | Verificación funcional posterior al reinicio de la VM y a los respaldos | 4.1, 4.4 | `dc3cf58f3acfbf9633c1be063153a1f4db074f0e745c009db25fbe4dc53e6f1c` |

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
- **Aprobación de la cátedra:** F0 aprobado, 100/100 (devolución informada por R1). F1 comenzó antes de recibirse esa devolución.
- **F1:** ejecutada el 08 y 09/10/2026 y aprobada, 100/100; estado en la lista F1 de esta sección.

- [x] IPAM de diseño: 9 enlaces `/30`, 2 LAN, 7 loopbacks `/32`, sin solapamiento (verificación matemática documentada)
- [x] Cuatro correcciones de diseño aplicadas; SPOF EDGE queda como recomendación
- [x] Política integrada de gestión, autenticación y servicios
- [x] Política de operación y change log documentados

### Topología, hardening y backup (F1)

**Devolución de la cátedra (informada por R1):** F1 aprobado, **Logrado, 100/100**, sin correcciones bloqueantes.

| Criterio | Nivel | Lo que destacó la cátedra |
| --- | :-: | --- |
| Topología e IP | 4 | Capturas organizadas, IPAM comprobado con ping y mapeo real de interfaces GNS3 |
| Hardening | 4 | Captura por router; control de servicios, administración MAC, Neighbor Discovery y ausencia de cliente DHCP |
| Backup inicial | 4 | Ocho exports F1 versionados, incluidos los dos de EDGE (08 y 09/10) |
| Operación | 4 | Restore de ISP-1, backups binarios cifrados y change log con los hashes de reversión corregidos (`1a8d0f2`) |

También destacó la trazabilidad del trabajo de los cinco integrantes. Observaciones de continuidad, no bloqueantes:

- Mantener el README legible sin necesidad de abrir la memoria. Se actualizó con el estado posterior a F1.
- Sostener backups independientes por hito en F2, F3 y los drills de F4 (planificación en 6.2).
- Las decisiones técnicas y la autoría son responsabilidad de los integrantes, aunque usemos asistencia de IA. La cátedra señaló el commit `2309460`, cuyo autor Git figura como "Claude" (6.1). No se reescribe el historial; los commits nuevos se hacen con la identidad Git real de cada integrante.

El registro de F1 que sigue conserva el estado al cierre del 09/10. La red SSH-MGMT y su segundo juego de backups son posteriores y se listan aparte.

**Criterios de aceptación de F1** (estructura del backlog de la consigna):

- [x] 7 CHR + 2 switches + 2 hosts desplegados y cableados: 11 nodos y 15 enlaces (2.1, 2.2)
- [x] IP de enlace y loopbacks de los 7 routers según el IPAM; 9 enlaces directos probados (3.0, 4.1)
- [x] PC-USER y SRV configurados y con conectividad a ambos DIST (3.8, 4.1)
- [x] Snapshot BASE registrado en GNS3 antes de configurar (2.3). Es un snapshot de GNS3; no se probó su restore
- [x] Hardening de los 7 routers (5.1), incluido el cambio de contraseña de `admin` (confirmación de R1). Al 09/10, SSH quedó temporalmente deshabilitado
- [x] Backup inicial `/export` de los 7 routers, sanitizado e integrado en `main` (6.2)

**Procedimientos adicionales de la política interna de backup (1.4)**, no exigidos por los criterios anteriores:

- [x] Backup binario `.backup` cifrado de los 7 routers, fuera del repositorio, con metadatos en 6.2: ejecutó R1; tamaño y SHA-256 verificados por R1. R5 no tuvo acceso a los binarios
- [x] Restore probado en un router con la misma versión de RouterOS: solo ISP-1, RouterOS 7.16, en proyecto aislado; satisfactorio, con capturas y comparación contra el export (6.2, 7.1). Los otros seis binarios no se restauraron
- [x] Recuperación del proyecto GNS3 desde el archivo portable, validada en una copia aislada (2.3). La importación estándar falló y el restore de snapshots individuales no se probó
- [ ] Procedimiento privado para reinyectar claves y reprovisionar usuarios de gestión
- [ ] Export `base` de cada router antes de configurar: no se generó; solo existe el snapshot GNS3

El ítem "Backups con restore probado" de Operación sigue sin marcar: F1 y SSH-MGMT tienen sus siete backups y un restore de ISP-1 cada uno, pero faltan los hitos F2 y F3 y los backups antes y después de cada drill.

**Pendientes operativos de F1:**

- [x] Definir el origen de gestión autorizado y habilitar SSH restringido a él: resuelto después del cierre de F1, el 14/10 (hito SSH-MGMT, abajo)
- [ ] Repetir la captura final de DIST-1 sin el comando `/export` previo (7.1)
- [ ] Capturas de R1 de la recuperación portable del proyecto GNS3 (las del restore de ISP-1 están en 7.1)

**Hito SSH-MGMT (14 a 16/10, posterior a F1):**

- [x] Red de gestión `172.31.250.0/28` con VRF `MGMT` en los 7 routers; SW-MGMT y MGMT-CLIENT agregados (2.4, 3.9). Ejecutó R1
- [x] SSH desde `172.31.250.10` aceptado y desde `172.31.250.11` rechazado en los 7 routers; enlaces de producción sin cambios (4.1). Ejecutó R1; sin capturas publicadas
- [x] Siete exports SSH-MGMT sanitizados en `backups/2026-10-14/`, PR #18 a #21 (6.2)
- [x] Siete backups binarios cifrados del 15/10, fuera del repositorio, con metadatos en 6.2. Ejecutó R1
- [x] Restore aislado de ISP-1 el 16/10: exitoso con ajuste manual de interfaces, direcciones y VRF (6.2, 7.2). Los otros seis binarios no se restauraron

### VRRP y OSPF (F2)

F2 se ejecutó el 16/10 y en la madrugada del 17/10. R1 configuró y probó los routers; R2, R3 y R4 publicaron sus exports (PR #23 a #26); R5 revisó y documentó la evidencia. Pendiente de la devolución de la cátedra. Detalle en la matriz de aceptación de 4.3.

- [x] VRRP USERS (VRID 10, master DIST-1) y SERVERS (VRID 20, master DIST-2), con load-sharing (3.10, 4.3)
- [x] Failover y recuperación VRRP verificados por R1; sin medición de tiempos (4.3)
- [x] Autenticación simple de VRRP en los dos grupos: configurada según los exports y confirmada por R1; las contraseñas no se publican (3.10)
- [x] OSPFv2 área 0 con MD5 en EDGE, CORE-1, CORE-2, DIST-1 y DIST-2; siete adyacencias en `Full`, incluida la core–core (3.10, 4.3)
- [x] Rutas a las LAN y loopbacks en EDGE, con ECMP (4.3)
- [x] Gateways virtuales, PC-USER ↔ SRV y ambas LAN → loopback de EDGE: 5/5 (4.1)
- [x] Exports F2 de los siete routers en `backups/2026-10-16/` (6.2)
- [x] Backups binarios F2 de los siete routers y exports originales, preservados por R1 con verificación SHA-512 (6.2)
- [x] Snapshots `PRE_F2_2026-10-16` y `F2_FINAL_VRRP_OSPF_2026-10-16` creados por R1 (6.2)
- [ ] Restore de algún backup de F2 o del snapshot `F2_FINAL_VRRP_OSPF_2026-10-16`: no se realizó
- [ ] Causa de los mensajes críticos de EDGE tras el reinicio del 17/10: no determinada (4.3)

### BGP y firewall (F3)

R5 configuró y probó F3 en su copia GNS3 del 19 al 25/10, con autorización de R1 en cada etapa. R1 validó la implementación y las pruebas. Los exports los publican R1 a R4 por PR, y R5 documentó la evidencia. Pendiente de la devolución de la cátedra. Detalle en la matriz de aceptación de 4.4.

- [x] eBGP EDGE ↔ ISP-1 (AS 65001) y EDGE ↔ ISP-2 (AS 65002) con TCP-MD5, las dos en `established` (3.11, 4.4)
- [x] Cada ISP anuncia su loopback /32 y el default; EDGE acepta solo eso, con filtros explícitos (3.11, 4.4)
- [x] EDGE anuncia solo USERS y SERVERS a los ISP, que tienen ruta de retorno; sin anuncio de la red de gestión (3.11, 4.4)
- [x] Default activo y loopbacks ISP propagados por OSPF, con filtro y sin redistribución indiscriminada (3.11, 4.4)
- [x] PC-USER y SRV alcanzan las dos loopbacks ISP con ping y traceroute (4.1)
- [x] Firewall de EDGE con `input` y `forward` separados; la gestión no responde desde los enlaces ISP (4.4, 5.3)
- [x] Caída y recuperación controlada de ISP-1 y de ISP-2; sin medición de tiempos (4.4)
- [x] Snapshots `PRE_F3_R5_2026-10-18`, `F3_FW_R5_2026-10-23` y `F3_FINAL_R5_2026-10-25` (6.2)
- [x] Respaldos privados post-F3 de los siete routers (export original y backup cifrado) y pre-firewall de EDGE, con SHA-512 y dos copias verificadas (6.2)
- [ ] Exports F3 de los siete routers en `backups/2026-10-25/`: auditados por R5, pendientes de las PR de R1 a R4 (6.2)
- [ ] Restore de algún backup de F3 o del snapshot `F3_FINAL_R5_2026-10-25`: no se realizó
- [ ] Revisión con R1 del alcance de la regla 9 de `forward` (5.3)

### Redes

- [x] 7 CHR + 2 switches + 2 hosts levantados y cableados (F1, 2.1)
- [x] VRRP operativo (2 grupos, load-sharing) (F2, 4.3)
- [x] OSPF área 0 con adyacencias (incluido core-core) (F2, 4.3)
- [x] BGP eBGP ×2 establecido (multi-homing) (F3, 4.4)
- [ ] Los 5 drills ejecutados y documentados

### Seguridad

- [x] Hardening aplicado (F1, 5.1; al 09/10 SSH quedó deshabilitado y desde el 14/10 está restringido a la red de gestión, 5.2)
- [x] OSPF MD5 funcionando (F2: siete adyacencias en `Full` con MD5, 3.10 y 4.3; la prueba con clave incorrecta es de F4)
- [x] BGP TCP-MD5 funcionando (F3: dos sesiones `established` con TCP-MD5, 4.4 y 5.3; la prueba con clave incorrecta es de F4)
- [x] VRRP auth funcionando (F2: `simple` en los dos grupos, confirmada por R1; el export saneado no muestra las contraseñas, 3.10)
- [x] Firewall edge aplicado (F3, 5.3)
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
- [ ] Capturas organizadas (F1 en 7.1, SSH-MGMT en 7.2, F2 en 7.3 y F3 en 7.4; faltan las de F4)
- [ ] Cada integrante puede defender su parte y una parte ajena
