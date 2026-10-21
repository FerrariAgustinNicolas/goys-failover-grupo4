# Backlog — Laboratorio Failover Routing

> **Grupo:** 4 · **Vencimiento final:** vie 23/10

## Leyenda de estado

- `[ ]` pendiente · `[~]` en curso · `[x]` hecho
- Cada tarea lleva **dueño** (rol): `[R1]` … `[R5]`.
- **"Hecho" requiere satisfacer el criterio de aceptación de esa fase y registrar evidencia revisable.** En F0, `[x]` acredita el diseño documentado en `docs/memoria.md` e integrado a `main` (PR #1 a #4); la cátedra aprobó F0 con 100/100. F1 también fue aprobado con 100/100. En F1–F5, `[x]` requiere ejecución y evidencia posteriores a F0.

---

## Epic F0 — Diseño y gestión de cambio · *vence vie 2/10*

### IPAM / direccionamiento
- [x] [R1] definir direccionamiento de EDGE, enlaces WAN y router-id de EDGE
- [x] [R2] definir router-id de ISP-1/ISP-2 y validar el diseño de las sesiones eBGP (integrado a `main` por PR #3, merge `e316152`)
- [x] [R3] definir enlace CORE-1 ↔ CORE-2 y router-id de CORE-1/CORE-2
- [x] [R4] definir enlaces CORE–DIST, LAN USERS/SERVERS, plan VRRP (VRID 10/20) y router-id de DIST-1/DIST-2

Nota: R1 auditó las 33 asignaciones del IPAM (18 redes únicas, 153 pares comparados, sin solapamiento).

### Corrección del diagrama (≥ 3 defectos)
- [x] [R1] documentar los defectos de EDGE/WAN e IPAM: defecto 1 (firewall único como SPOF; justificar el uso de un par HA en producción), defecto 2 (iBGP Route Reflector mal ubicado → eBGP directo EDGE–ISP) y defecto 5 (subredes solapadas → nueve `/30` disjuntas, dos LAN y siete loopbacks `/32`)
- [x] [R4] defecto 3: HSRP en el core → VRRP en distribución
- [x] [R3] defecto 4: falta el enlace core–core (habilita tránsito directo; preferencia OSPF depende de costos a validar en F2)

La corrección del solapamiento y su integración IPAM reúnen aportes de R1–R4.

### Política de seguridad
- [x] [R1] política de seguridad de EDGE (usuarios, servicios, firewall y claves BGP TCP-MD5) y consolidación de la política integrada del grupo en 1.3 (consolidación integrada a `main` por PR #3, merge `e316152`)
- [x] [R4] política de seguridad de DIST: usuarios, servicios y claves VRRP
- [x] [R3] política de seguridad de CORE: usuarios, servicios y clave OSPF MD5
- [x] [R2] política de seguridad de ISP-1/ISP-2 (integrado a `main` por PR #3, merge `e316152`)

### Política de operación (change log + backup)
- [x] [R5] formato del change log y convención de commits (memoria 1.4)
- [x] [R5] política de backup: cuándo, cómo, versionado, restore y datos sensibles (memoria 1.4)
- [x] [R5] change log con los commits de F0 (memoria 6.1)

### Repositorio git
- [x] [R1] estructura inicial del repo e integrantes y roles en el README
- [x] [R5] `backlog.md` armado desde la plantilla, con dueño por tarea
- [x] [R1] integrar a `main` por PR las ramas de F0: PR #1 (R4, `58db8cd`), PR #2 (R3, `5427689`), PR #4 (R5, `e35fdeb`) y PR #3 (R2 y consolidación, `e316152`). R5 solo actualiza el estado

---

## Epic F1 — Topología + hardening + backup · *vence vie 9/10*

Nota: la única instancia GNS3 operativa está en el equipo de R1, que ejecutó la configuración y las pruebas de F1 en los siete routers y en los hosts. Cada `[x]` conserva su dueño original y se respalda con la evidencia indicada; R5 verificó y documentó esa evidencia (memoria 3.0).

### Despliegue (7 CHR + 2 switches + 2 hosts)
- [x] [R1] levantar el proyecto GNS3 `topologia_failover_routing` con los 7 CHR (memoria 2.1)
- [x] [R1] relevar los nombres de interfaz y completarlos en el IPAM (memoria 1.2; correspondencia GNS3 ↔ RouterOS en 2.2)
- [x] [R5] levantar SW-USERS, SW-SERVERS, PC-USER y SRV y cablearlos a DIST-1/DIST-2. Ejecutó R1 (memoria 2.1 y 2.2)
- [x] [R5] configurar PC-USER (`192.168.10.100/24`, gw `192.168.10.1`) y SRV (`192.168.20.100/24`, gw `192.168.20.1`). Ejecutó R1 (memoria 3.8 y 4.1)

### IPs de enlace + loopbacks
- [x] [R1] IPs de enlace y loopback de EDGE (memoria 3.0 y 4.1)
- [x] [R2] IPs de enlace y loopback de ISP-1/ISP-2. Ejecutó R1 (memoria 3.0 y 4.1)
- [x] [R3] IPs de enlace y loopback de CORE-1/CORE-2. Ejecutó R1 (memoria 3.0 y 4.1)
- [x] [R4] IPs de enlace y loopback de DIST. Ejecutó R1 (memoria 3.0 y 4.1)

### Snapshot BASE

Nota: R1 creó los snapshots GNS3 `F1_BASE_2026-10-08_sin-configurar` y `F1_FINAL_2026-10-09`, y validó la recuperación del proyecto desde el archivo portable en una copia aislada (memoria 2.3). Los snapshots no son backups de RouterOS y su restore individual no se probó. Las tareas siguientes son de la política interna 1.4.

- [ ] [R5] obtener y revisar un `/export` sanitizado de cada uno de los 7 routers antes de configurar; publicar solo esos `.rsc` y metadatos no sensibles. No se generó antes de configurar (memoria 6.2); ajuste de la tarea propuesto a R1
- [x] [R5] guardar los backups binarios completos cifrados fuera del repositorio público, en almacenamiento privado con acceso controlado; indicar solo un localizador privado no secreto y registrar metadatos, checksum y resultado en 6.1/6.2. Ejecutó R1 (siete `.backup` con `aes-sha256`, verificados por R1); R5 verificó la documentación, sin acceso a los binarios (memoria 6.2). No se informaron exports sensibles
- [x] [R5] probar en F1 el restore del backup privado en un router de la misma versión de RouterOS, con evidencia redactada en 6.2. Ejecutó R1: ISP-1, RouterOS 7.16, proyecto aislado, satisfactorio; los otros seis binarios no se restauraron (memoria 6.2). Capturas y comparación con el export en memoria 6.2 y 7.1
- [ ] [R5] documentar el protocolo privado para inyectar las claves de laboratorio y provisionar usuarios de gestión (memoria 6.2). Debe incluir la revisión de interfaces, direcciones y VRF tras un restore en otra VM, según el restore del 16/10

### Hardening (los 7 routers)
Nota: al cierre de F1 (09/10), SSH quedó temporalmente deshabilitado en los siete routers hasta definir el origen de gestión autorizado (memoria 5.1). Se habilitó restringido el 14/10, después de F1 (ver "Red de gestión SSH-MGMT").

- [x] [R1] hardening de EDGE (memoria 5.1)
- [x] [R2] hardening de ISP-1/ISP-2. Ejecutó R1 (memoria 5.1)
- [x] [R3] hardening de CORE-1/CORE-2. Ejecutó R1 (memoria 5.1)
- [x] [R4] hardening de DIST-1/DIST-2. Ejecutó R1 (memoria 5.1)

### Backup inicial (`/export`)
- [x] [R1] backup `/export` de EDGE: `backups/2026-10-09/EDGE_2026-10-09_f1.rsc`, PR #11 (merge `170975b`)
- [x] [R2] backup `/export` de ISP-1/ISP-2: PR #12 (merge `83119f5`)
- [x] [R3] backup `/export` de CORE-1/CORE-2: PR #10 (merge `6beba24`)
- [x] [R4] backup `/export` de DIST: PR #13 (merge `703c5b9`)

### Devolución de F1

Nota: la cátedra aprobó F1 con 100/100 (nivel 4 en los cuatro criterios), sin correcciones bloqueantes (memoria 10). Las observaciones de continuidad no generan tareas nuevas:

- Pendiente de SSH tras F1: resuelto el 14/10 con la red SSH-MGMT (sección siguiente).
- README con afirmaciones desactualizadas ("F1 sin aprobación" y "SSH pendiente"): corregido y con el estado posterior a F1.
- Verificación de interfaces pedida en la devolución de F0: atendida en `341c938` (memoria 1.2 y 2.2).
- Commit `2309460` con autor Git "Claude": observación de trazabilidad, no bloqueante. No se reescribe el historial; los commits nuevos se hacen con la identidad Git real de cada integrante.
- Backups independientes por hito en F2, F3 y F4: quedan en las tareas de backup de cada epic, pendientes hasta que existan los archivos.

### Red de gestión SSH-MGMT (posterior a F1, 14 a 16/10)

Nota: R1 configuró y probó la red de gestión en GNS3; R2, R3 y R4 publicaron los exports de sus routers y R5 documentó y verificó la evidencia.

- [x] [R1] agregar SW-MGMT y MGMT-CLIENT y conectar los siete routers a la red `172.31.250.0/28` (memoria 2.4)
- [x] [R1] configurar VRF `MGMT`, dirección de gestión, tres reglas de firewall de entrada y SSH restringido a `172.31.250.10/32` con `strong-crypto` en los siete routers (memoria 3.9 y 5.2)
- [x] [R1] verificar SSH desde `172.31.250.10`, rechazo desde `172.31.250.11` y conectividad de los enlaces de producción en los siete routers (memoria 4.1; sin capturas publicadas)
- [x] [R2] export SSH-MGMT de ISP-1/ISP-2: PR #18 (merge `b38ee30`)
- [x] [R4] export SSH-MGMT de DIST-1/DIST-2: PR #19 (merge `dc57333`)
- [x] [R3] export SSH-MGMT de CORE-1/CORE-2: PR #20 (merge `e5ed9e8`)
- [x] [R1] export SSH-MGMT de EDGE: PR #21 (merge `102f1a1`)
- [x] [R5] coordinar el backup binario SSH-MGMT de los siete routers y registrar sus metadatos en 6.1 y 6.2. Ejecutó R1 el 15/10 (`aes-sha256`, tamaños y SHA-256 verificados por R1); R5 no tuvo acceso a los binarios
- [x] [R5] probar el restore de un backup SSH-MGMT en un router aislado. Ejecutó R1 el 16/10 con ISP-1: exitoso con ajuste manual de interfaces, direcciones y VRF; los otros seis no se restauraron (memoria 6.2 y 7.2)
- [x] [R5] documentar SSH-MGMT, backups y restore en la memoria y el README, e incorporar las capturas (memoria 2.4, 3.9, 4.1, 5.2, 6.2 y 7.2)

---

## Epic F2 — VRRP + OSPF · *vence vie 16/10*

Nota: F2 se ejecutó el 16/10 y en la madrugada del 17/10. R1 configuró y probó los routers en la única instancia GNS3 operativa (proyecto `topologia_failover_F1_SSH_MGMT`). R2, R3 y R4 revisaron y publicaron los exports de sus routers, y R1 el de EDGE (PR #23 a #26). R5 revisó las 17 capturas y los exports y documentó la evidencia (memoria 3.10, 4.1, 4.3, 6.2 y 7.3). Cada `[x]` conserva su dueño original. Las pruebas de failover de F2 no reemplazan los drills cronometrados de F4.

### VRRP (2 grupos, load-sharing, auth)
- [x] [R4] configurar VRRP vrid 10 en DIST-1 (master). Ejecutó R1: prioridad 150 en DIST-1 y 100 en DIST-2, IP virtual `192.168.10.1` (memoria 3.10; Figura 1; export de DIST-1, PR #25)
- [x] [R4] configurar VRRP vrid 20 en DIST-2 (master). Ejecutó R1: prioridad 150 en DIST-2 y 100 en DIST-1, IP virtual `192.168.20.1` (memoria 3.10; Figuras 2 y 3; export de DIST-2, PR #25)
- [x] [R4] activar auth simple en ambos grupos. Ejecutó R1: `authentication=simple` en los dos grupos de ambos DIST, según los exports. R1 confirmó que las contraseñas se configuraron durante F2 y se ocultaron al preparar los exports públicos; el export saneado no permite comprobar que coincidan entre DIST-1 y DIST-2 (memoria 3.10)
- [x] [R5] verificar master/backup con `/interface vrrp print`. Ejecutó R1, incluidos el failover y la recuperación de los dos grupos; R5 revisó las Figuras 1 a 5. No se midieron tiempos (memoria 4.3)

### OSPF área 0 (con MD5, incluido core–core)
- [x] [R3] OSPF con MD5 en CORE-1/CORE-2, incluida la adyacencia core–core. Ejecutó R1 (memoria 3.10; exports de CORE, PR #24)
- [x] [R1] OSPF con MD5 en EDGE hacia CORE-1/CORE-2 (memoria 3.10; export de EDGE, PR #23)
- [x] [R4] OSPF con MD5 en DIST. Ejecutó R1; LAN y loopback como interfaces pasivas (memoria 3.10; exports de DIST, PR #25)
- [x] [R3] verificar todas las adyacencias en `Full` con `/routing ospf neighbor print`. Ejecutó R1: siete adyacencias en `Full`, vistas desde EDGE, CORE-1 y CORE-2 (memoria 4.3; Figuras 6 a 8). Rutas a las LAN y loopbacks con ECMP en EDGE (Figuras 9 y 10)

### Verificación L3 (ping intra-LAN + gateway virtual)
- [x] [R5] ping de PC-USER a `192.168.10.1` y de SRV a `192.168.20.1` (gateway virtual). Ejecutó R1: 5/5 (memoria 4.1; Figuras 4 y 5)
- [x] [R5] ping entre PC-USER y SRV a través de distribución. Ejecutó R1: 5/5 en ambos sentidos; también 5/5 desde ambas LAN a la loopback de EDGE (memoria 4.1; Figuras 11 a 14). Tras la parada y el arranque, PC-USER → SRV 5/5 (Figura 16)
- [x] [R5] coordinar el backup post-F2 de los 7 routers (export sanitizado y binario cifrado, juego independiente del de F1 y SSH-MGMT) y registrarlo en 6.1 y 6.2. Exports en `backups/2026-10-16/` (PR #23 a #26); R1 generó los siete binarios con `aes-sha256` solicitado y preservó los 14 archivos privados con verificación SHA-512. El export de ISP-1 vigente es el corregido del 19/10, por referencias inválidas en el original. No se restauró ningún backup de F2 (memoria 6.2)

Pendientes que deja F2:

- [ ] [R5] probar el restore de al menos un backup de F2 o del snapshot `F2_FINAL_VRRP_OSPF_2026-10-16`; no se realizó
- [ ] [R1] registrar la causa de los mensajes `kernel failure in previous boot` y `router was rebooted without proper shutdown` de EDGE (17/10), si se llega a determinar con evidencia (memoria 4.3)

---

## Epic F3 — BGP + firewall · *vence vie 16/10*

### eBGP multi-homing (2 sesiones, TCP-MD5)
- [ ] [R1] sesiones eBGP de EDGE (AS 65000) hacia ISP-1 e ISP-2 con TCP-MD5
- [ ] [R2] sesiones eBGP de ISP-1 (AS 65001) e ISP-2 (AS 65002) hacia EDGE con TCP-MD5
- [ ] [R2] anunciar por eBGP desde cada ISP su propia loopback `/32` (`10.255.255.1/32` o `10.255.255.2/32`) junto con el default hacia EDGE
- [ ] [R1] verificar las dos sesiones en `established` con `/routing bgp session print`

### Redistribución OSPF→BGP
- [ ] [R1] redistribuir en EDGE las redes internas aprendidas por OSPF hacia las sesiones eBGP
- [ ] [R2] verificar en ISP-1 e ISP-2 que se reciben las LAN USERS y SERVERS

### Salida a "Internet" (host → loopback ISP)
- [ ] [R1] propagar por OSPF hacia CORE y DIST el default activo de los ISP; redistribuir con control/filtro las loopbacks ISP `/32` para que cada destino use su proveedor conectado
- [ ] [R5] ping y traceroute desde PC-USER y SRV a las loopbacks de ISP-1 e ISP-2 con cada proveedor disponible
- [ ] [R5] coordinar el backup post-F3 de los 7 routers (export sanitizado y binario cifrado, juego independiente) y registrarlo en 6.1 y 6.2

### Firewall edge (filtro + plano de gestión)
- [ ] [R1] reglas de filtro en EDGE según 1.3: separar input/forward; BGP TCP/179 solo ISP peers, OSPF IP/89 solo CORE neighbors, SSH solo gestión; established/related y rechazo de entrada no solicitado; permitir USERS/SERVERS a loopbacks ISP y retorno
- [ ] [R1] restringir SSH de EDGE al allowlist de gestión relevado en F1; Winbox permanece deshabilitado. Avance: desde el 14/10, SSH de EDGE solo acepta `172.31.250.10/32` en la VRF `MGMT` (memoria 3.9); falta integrarlo con las reglas de entrada de F3
- [ ] [R5] verificar que la salida a Internet sigue funcionando y que la gestión de EDGE no responde desde los ISP

---

## Epic F4 — Drills + monitoreo · *vence mar 20/10*

### Los 5 drills (runbook + post-mortem + tiempo)
- [ ] [R5] runbook de cada drill en `runbooks/` (objetivo, pasos, resultado esperado y vuelta atrás)
- [ ] [R5] ejecutar los 5 drills con backup antes y después (`pre-drillN` / `post-drillN`, registrados en 6.1 y 6.2), midiendo el tiempo de reconvergencia
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
- [ ] [R1] consolidar la memoria: secciones 3 y 5 con el aporte de cada rol, conclusiones y referencias
- [ ] [R5] completar gestión operativa (6.1 a 6.3) y organizar las capturas (sección 7)
- [ ] [R5] verificar que el change log refleje todos los commits de `main`

### Backlog cerrado (todo en "hecho")
- [ ] [R5] revisar cada tarea contra su criterio de aceptación y marcarla como hecha
- [ ] [R1] validar el cierre del backlog antes de la entrega

### Defensa oral (parte propia + ajena)
- [ ] [R1] asignar a cada integrante la parte ajena que va a defender
- [ ] [R1] coordinar un ensayo general de la defensa antes del 23/10
