# Backlog — Laboratorio Failover Routing

> **Grupo:** 4 · **Vencimiento final:** vie 23/10

## Leyenda de estado

- `[ ]` pendiente · `[~]` en curso · `[x]` hecho
- Cada tarea lleva **dueño** (rol): `[R1]` … `[R5]`.
- **"Hecho" = criterio de aceptación cumplido** (ver spec, sección 6). No "más o menos".

---

## Epic F0 — Diseño y gestión de cambio · *vence vie 2/10*

### IPAM / direccionamiento
- [x] [R1] direccionamiento de EDGE, enlaces WAN y router-id de EDGE
- [x] [R4] enlaces CORE–DIST, LAN USERS/SERVERS, plan VRRP (VRID 10/20) y router-id de DIST-1/DIST-2
- [x] [R3] enlace CORE-1 ↔ CORE-2 y router-id de CORE-1/CORE-2
- [ ] [R2] router-id de ISP-1/ISP-2 y sesiones eBGP (en rama `docs/f0-r2-proveedores`, falta integrar a `main`)

### Corrección del diagrama (≥ 3 defectos)
- [ ] [R1] defecto 1: firewall sin par de alta disponibilidad (SPOF); recomendación para producción, no aplicada en el laboratorio
- [x] [R1] defecto 2: iBGP Route Reflector mal ubicado → eBGP directo EDGE–ISP
- [x] [R4] defecto 3: HSRP en el core → VRRP en distribución
- [x] [R3] defecto 4: falta el enlace core–core

### Política de seguridad
- [ ] [R1] consolidar la política de seguridad integrada del grupo en 1.3 (usuarios, servicios, alcance de gestión y autenticación); tarea F0, no postergada a F5
- [x] [R1] política de seguridad de EDGE: usuarios, servicios, firewall y claves BGP TCP-MD5
- [x] [R4] política de seguridad de DIST: usuarios, servicios y claves VRRP
- [x] [R3] política de seguridad de CORE: usuarios, servicios y clave OSPF MD5
- [ ] [R2] política de seguridad de ISP-1/ISP-2 (en rama `docs/f0-r2-proveedores`, falta integrar a `main`)

### Política de operación (change log + backup)
- [x] [R5] formato del change log y convención de commits (memoria 1.4)
- [x] [R5] política de backup: cuándo, cómo, versionado, restore y datos sensibles (memoria 1.4)
- [x] [R5] change log con los commits de F0 (memoria 6.1)

### Repositorio git
- [x] [R1] estructura inicial del repo e integrantes y roles en el README
- [x] [R5] `backlog.md` armado desde la plantilla, con dueño por tarea
- [ ] [R1] integrar a `main` por PR las ramas pendientes de F0 (R2 y R5)

---

## Epic F1 — Topología + hardening + backup · *vence vie 9/10*

### Despliegue (7 CHR + 2 switches + 2 hosts)
- [ ] [R1] levantar el proyecto GNS3 `topologia_failover_routing` con los 7 CHR
- [ ] [R1] relevar los nombres de interfaz y completarlos en el IPAM (memoria 1.2)
- [ ] [R5] levantar SW-USERS, SW-SERVERS, PC-USER y SRV y cablearlos a DIST-1/DIST-2
- [ ] [R5] configurar PC-USER (`192.168.10.100/24`, gw `192.168.10.1`) y SRV (`192.168.20.100/24`, gw `192.168.20.1`)

### IPs de enlace + loopbacks
- [ ] [R1] IPs de enlace y loopback de EDGE
- [ ] [R2] IPs de enlace y loopback de ISP-1/ISP-2
- [ ] [R3] IPs de enlace y loopback de CORE-1/CORE-2
- [ ] [R4] IPs de enlace y loopback de DIST

### Snapshot BASE
- [ ] [R5] obtener y revisar un `/export` sanitizado de cada uno de los 7 routers antes de configurar; publicar solo esos `.rsc` y metadatos no sensibles
- [ ] [R5] guardar los backups binarios completos y cualquier export sensible cifrados fuera del repositorio público, en almacenamiento privado con acceso controlado; indicar solo un localizador privado no secreto y registrar metadatos, checksum y resultado en 6.1/6.2
- [ ] [R5] probar en F1 el restore del backup privado en un router de la misma versión de RouterOS; documentar el protocolo privado para inyectar las claves de laboratorio y provisionar usuarios de gestión, con evidencia redactada en 6.2

### Hardening (los 7 routers)
- [ ] [R1] hardening de EDGE
- [ ] [R2] hardening de ISP-1/ISP-2
- [ ] [R3] hardening de CORE-1/CORE-2
- [ ] [R4] hardening de DIST-1/DIST-2

### Backup inicial (`/export`)
- [ ] [R1] backup `/export` de EDGE
- [ ] [R2] backup `/export` de ISP-1/ISP-2
- [ ] [R3] backup `/export` de CORE-1/CORE-2
- [ ] [R4] backup `/export` de DIST

---

## Epic F2 — VRRP + OSPF · *vence vie 16/10*

### VRRP (2 grupos, load-sharing, auth)
- [ ] [R4] configurar VRRP vrid 10 en DIST-1 (master)
- [ ] [R4] configurar VRRP vrid 20 en DIST-2 (master)
- [ ] [R4] activar auth simple en ambos grupos
- [ ] [R5] verificar master/backup con `/interface vrrp print`

### OSPF área 0 (con MD5, incluido core–core)
- [ ] [R3] OSPF con MD5 en CORE-1/CORE-2, incluida la adyacencia core–core
- [ ] [R1] OSPF con MD5 en EDGE hacia CORE-1/CORE-2
- [ ] [R4] OSPF con MD5 en DIST
- [ ] [R3] verificar todas las adyacencias en `Full` con `/routing ospf neighbor print`

### Verificación L3 (ping intra-LAN + gateway virtual)
- [ ] [R5] ping de PC-USER a `192.168.10.1` y de SRV a `192.168.20.1` (gateway virtual)
- [ ] [R5] ping entre PC-USER y SRV a través de distribución
- [ ] [R5] coordinar el backup post-F2 de los 7 routers y registrarlo en 6.1 y 6.2

---

## Epic F3 — BGP + firewall · *vence vie 16/10*

### eBGP multi-homing (2 sesiones, TCP-MD5)
- [ ] [R1] sesiones eBGP de EDGE (AS 65000) hacia ISP-1 e ISP-2 con TCP-MD5
- [ ] [R2] sesión eBGP de ISP-1 (AS 65001) hacia EDGE con TCP-MD5
- [ ] [R2] sesión eBGP de ISP-2 (AS 65002) hacia EDGE con TCP-MD5
- [ ] [R1] verificar las dos sesiones en `established` con `/routing bgp session print`

### Redistribución OSPF→BGP
- [ ] [R1] redistribuir en EDGE las redes internas aprendidas por OSPF hacia las sesiones eBGP
- [ ] [R2] verificar en ISP-1 e ISP-2 que se reciben las LAN USERS y SERVERS

### Salida a "Internet" (host → loopback ISP)
- [ ] [R1] propagar por OSPF hacia CORE y DIST la ruta por defecto aprendida de los ISP
- [ ] [R5] ping y traceroute desde PC-USER y SRV a las loopbacks de ISP-1 e ISP-2
- [ ] [R5] coordinar el backup post-F3 de los 7 routers y registrarlo en 6.1 y 6.2

### Firewall edge (filtro + plano de gestión)
- [ ] [R1] reglas de filtro en EDGE según 1.3 (BGP con los ISP, established/related, descarte del resto)
- [ ] [R1] restringir SSH/Winbox de EDGE al plano de gestión
- [ ] [R5] verificar que la salida a Internet sigue funcionando y que la gestión de EDGE no responde desde los ISP

---

## Epic F4 — Drills + monitoreo · *vence mar 20/10*

### Los 5 drills (runbook + post-mortem + tiempo)
- [ ] [R5] runbook de cada drill en `runbooks/` (objetivo, pasos, resultado esperado y vuelta atrás)
- [ ] [R5] ejecutar los 5 drills con backup antes y después, midiendo el tiempo de reconvergencia
- [ ] [R5] post-mortem de cada drill y post-mortem global

### Monitoreo (SNMP/chequeos)
- [ ] [R5] definir qué se monitorea (enlaces, vecinos OSPF, sesiones BGP, estado VRRP) y con qué herramienta
- [ ] [R5] habilitar SNMP o chequeos en los 7 routers, coordinando con el dueño de cada uno
- [ ] [R5] documentar el monitoreo en la memoria (6.3) con capturas

### Verificación de seguridad (clave incorrecta falla)
- [ ] [R3] OSPF: clave MD5 incorrecta en un extremo, verificar que la adyacencia no se forma y restaurar
- [ ] [R1] BGP: clave TCP-MD5 incorrecta en EDGE, verificar que la sesión no se establece y restaurar
- [ ] [R4] VRRP: clave incorrecta en un DIST, verificar el efecto sobre el grupo y restaurar
- [ ] [R5] registrar cada prueba en el change log (6.1) con su reversión

---

## Epic F5 — Memoria + defensa · *vence vie 23/10*

### Memoria (plantilla completa)
- [ ] [R1] consolidar la memoria: secciones 3 y 5 con el aporte de cada rol, política integrada (1.3), conclusiones y referencias
- [ ] [R5] completar gestión operativa (6.1 a 6.3) y organizar las capturas (sección 7)
- [ ] [R5] verificar que el change log refleje todos los commits de `main`

### Backlog cerrado (todo en "hecho")
- [ ] [R5] revisar cada tarea contra su criterio de aceptación y marcarla como hecha
- [ ] [R1] validar el cierre del backlog antes de la entrega

### Defensa oral (parte propia + ajena)
- [ ] [R1] asignar a cada integrante la parte ajena que va a defender
- [ ] [R1] coordinar un ensayo general de la defensa antes del 23/10
