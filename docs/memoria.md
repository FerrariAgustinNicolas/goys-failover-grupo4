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
| 1 | Firewall sin par de alta disponibilidad, generando un punto único de falla (SPOF). | En un entorno productivo se utilizaría un par de firewalls en alta disponibilidad/failover. | Un único firewall puede interrumpir la conectividad entre la red interna e Internet ante una falla del dispositivo. Un par redundante permite mantener el servicio si uno de los equipos queda fuera de operación. |
| 2 | iBGP Route Reflector mal ubicado en el diseño original. | Se utiliza eBGP directamente entre EDGE (AS 65000) e ISP-1 (AS 65001) / ISP-2 (AS 65002), sin Route Reflector. | Los proveedores pertenecen a sistemas autónomos diferentes, por lo que corresponde utilizar eBGP. En esta topología no existe necesidad de incorporar un Route Reflector iBGP. |
| 3 | Pendiente de completar por R3/R4. | Pendiente. | Pendiente. |

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
| CORE-1 ↔ CORE-2 | Pendiente R3 | Pendiente R3 | Pendiente R3 |
| CORE-1 ↔ DIST-1 | `10.255.0.20/30` | CORE-1: `10.255.0.21` / interfaz pendiente | DIST-1: `10.255.0.22` / interfaz pendiente |
| CORE-1 ↔ DIST-2 | `10.255.0.24/30` | CORE-1: `10.255.0.25` / interfaz pendiente | DIST-2: `10.255.0.26` / interfaz pendiente |
| CORE-2 ↔ DIST-1 | `10.255.0.28/30` | CORE-2: `10.255.0.29` / interfaz pendiente | DIST-1: `10.255.0.30` / interfaz pendiente |
| CORE-2 ↔ DIST-2 | `10.255.0.32/30` | CORE-2: `10.255.0.33` / interfaz pendiente | DIST-2: `10.255.0.34` / interfaz pendiente |
| USERS | `192.168.10.0/24` | DIST-1: `192.168.10.2` / DIST-2: `192.168.10.3` (interfaz pendiente) | Gateway VRRP: `192.168.10.1` · PC-USER: `192.168.10.100` |
| SERVERS | `192.168.20.0/24` | DIST-1: `192.168.20.2` / DIST-2: `192.168.20.3` (interfaz pendiente) | Gateway VRRP: `192.168.20.1` · SRV: `192.168.20.100` |

> **Aporte R4 — enlaces CORE ↔ DIST:** se continúa la numeración consecutiva de `/30` a partir del bloque que sigue a EDGE. Queda reservado `10.255.0.16/30` para CORE-1 ↔ CORE-2 (a confirmar por R3). Convención: el CORE toma la primera IP utilizable y el DIST la segunda de cada `/30`. Las direcciones del lado CORE son una propuesta de R4, sujeta a la confirmación de R3.
>
> **Direccionamiento de las LAN:** en cada LAN, `.1` es la IP virtual VRRP (gateway de los hosts), `.2` es DIST-1, `.3` es DIST-2 y `.100` es el host.

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
| ISP-1 | Pendiente R2 |
| ISP-2 | Pendiente R2 |
| EDGE | `10.255.255.3/32` |
| CORE-1 | Pendiente R3 |
| CORE-2 | Pendiente R3 |
| DIST-1 | `10.255.255.6/32` |
| DIST-2 | `10.255.255.7/32` |

Numeración propuesta, consecutiva y en el orden de las capas: ISP-1 `.1`, ISP-2 `.2`, EDGE `.3`, CORE-1 `.4`, CORE-2 `.5`, DIST-1 `.6`, DIST-2 `.7`. Los DIST usan su loopback como router-id de OSPF.

La asignación de EDGE forma parte del diseño de R1. Las restantes direcciones serán completadas por los responsables correspondientes manteniendo el bloque reservado y verificando que no existan duplicaciones.

### 1.3 Política de seguridad

#### Claves de autenticación

Las claves utilizadas serán exclusivas del entorno de laboratorio y no corresponderán a contraseñas personales ni a credenciales reutilizadas en otros servicios.

| Mecanismo | Enlace / grupo | Clave de laboratorio | Responsable |
| --- | --- | --- | --- |
| BGP TCP-MD5 | EDGE ↔ ISP-1 | `G4-BGP-ISP1-26` | R1 / R2 |
| BGP TCP-MD5 | EDGE ↔ ISP-2 | `G4-BGP-ISP2-26` | R1 / R2 |
| OSPF MD5 | Área 0 | Pendiente de definición | R3 |
| VRRP | USERS — VRID 10 | Pendiente de definición | R4 |
| VRRP | SERVERS — VRID 20 | Pendiente de definición | R4 |

Las claves BGP se mantienen separadas para cada proveedor, de modo que una misma credencial no sea compartida por ambas sesiones eBGP.

Las claves de OSPF y VRRP serán incorporadas por los responsables correspondientes antes de cerrar F0.

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

#### Política integrada del grupo

- **Usuarios y privilegios:** pendiente de consolidación.
- **Servicios a deshabilitar:** pendiente de consolidación.
- **Autenticación OSPF:** pendiente R3.
- **Autenticación BGP:** TCP-MD5 con claves independientes para cada sesión eBGP, definidas en la tabla de claves de autenticación.
- **Autenticación VRRP:** pendiente R4.

### 1.4 Política de operación

- **Formato del change log:** pendiente R5.
- **Política de backup:** pendiente R5.

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

Pendiente R5.

### 6.2 Backups

Pendiente R5.

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
