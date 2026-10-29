# F4_00 — Plan y preflight de F4 (R5)

**Fecha:** 29/10/2026 · **Preparó:** R5 (Lorenzo Bellomo), con asistencia de Claude · **Revisa:** R1.
**Alcance autorizado por R1:** inspección, análisis y preparación del checkpoint. No se ejecutaron drills, no se modificaron routers ni claves, no se habilitaron servicios, no se restauraron snapshots y no se creó ninguna PR.
**Ubicación:** rama local `docs/f4-r5-preflight` (desde `main` = `a423e04`, merge de la PR #32), carpeta `runbooks/F4/`. **Sin commit ni push.**

> **Estado de este informe:** la línea base en vivo (sección 1.3) se completó el 29/10 entre las 15:07 y las 16:44 UTC, en modo solo lectura. Solo quedan pendientes los pings originados en SRV. El bloqueante B1, el PID huérfano de GNS3, se resolvió con autorización de R5. Hubo un incidente menor en PC-USER, revertido; está registrado en 1.3.

---

## 1. Estado del laboratorio y recursos

### 1.1 Host Windows (medido el 29/10)

| Dato | Valor | Observación |
| --- | --- | --- |
| CPU | 12 procesadores lógicos | La VM tiene asignados los 12 |
| RAM | 7877 MB en total; **~1060 MB libres** con la VM apagada | La VM pide 5524 MB: el host queda al límite y pagina |
| Disco `C:` | 240 GB en total, **11 GB libres (96 % usado)** | Poco margen para snapshots y copias |
| Hipervisor | VirtualBox 7.2, con Hyper-V/VBS activo en Windows | Sin VT-x anidado: los CHR corren con **TCG** (emulación), según el checkpoint 0 de F3 |
| Permisos | `Get-VM` de Hyper-V denegado; VirtualBox accesible | — |

### 1.2 VM y proyecto GNS3 (lectura de la configuración, sin encenderla)

| Dato | Valor |
| --- | --- |
| VM | `SeguridadUbuntu1`: Ubuntu, kernel `7.0.0-38-generic`, 5524 MB, 12 vCPU, `nested-hw-virt=on`, NIC 1 NAT y NIC 2 host-only |
| Disco activo de la VM | Disco diferencial `Snapshots/{d1bc5bb8-…}.vdi` (6,96 GB) sobre la base `SeguridadUbuntu1.vdi` (9,76 GB) |
| Snapshot de VirtualBox | Uno solo, **`Pre-Lab`**, y la VM corre encima de él |
| Estado | Apagada desde el 26/10 16:13 UTC; **encendida el 29/10 a las 14:36 UTC** |
| Proyecto GNS3 activo | `~/GNS3/projects/f21d991d-8b14-408f-ae61-219b584978d9/failover_F2.gns3`, guardado el 25/10 a las 15:47 |
| Discos activos | `project-files/qemu/` de esa carpeta: **8 `hda_disk.qcow2`** (7 routers y MGMT-CLIENT), modificados el 25/10 entre las 15:55 y las 17:05. Coincide con los backups (16:18 a 16:23) y con la verificación final (17:05) de F3 |
| Copia anidada | La subcarpeta `failover_F3/` (772 MB) tiene otro `failover_F3.gns3` (25/10 15:46), sus propios `project-files` (35 MB) y `snapshots` (609 MB). **Sus 8 discos son del 19/10, anteriores a F3.** Abrir ese `.gns3` por error cargaría un estado viejo |
| Snapshots GNS3 | Los 8 existen en `snapshots/` (1,3 GB): `F1_BASE_2026-10-08_sin-configurar`, `F1_FINAL_2026-10-09`, `SSH_MGMT_7_ROUTEROS_VALIDADO`, `PRE_F2_2026-10-16`, `F2_FINAL_VRRP_OSPF_2026-10-16`, `PRE_F3_R5_2026-10-18` (19/10 16:13), `F3_FW_R5_2026-10-23` (23/10 22:35, 342 MB) y `F3_FINAL_R5_2026-10-25` (25/10 14:16, 342 MB) |

> **Riesgo crítico:** el snapshot de VirtualBox `Pre-Lab` es anterior al laboratorio. **Restaurarlo borraría el proyecto GNS3 y todo F3.** Nadie debe usar "Restaurar snapshot" en VirtualBox.

### 1.3 Línea base mínima en vivo

Se hace en modo solo lectura: R5 inicia sesión en cada consola y Claude ejecuta solo `print`, sin `export` ni `connection print`.

| Verificación | Comando | Esperado (cierre de F3, 25/10) | Resultado |
| --- | --- | --- | --- |
| Recursos de la VM (reposo, sin GNS3) | `uptime`, `free -m`, `df -h /`, `nproc` | Carga ~12 con los nodos encendidos | 29/10 15:07 UTC: carga 0,56 / 0,27 / 0,40; 12 CPU; RAM 4793 MB, 3527 disponibles; swap 4095 MB sin uso; `/` de 25 GB con 16 GB usados y **8,2 GB libres (65 %)** |
| Discos del proyecto | `find … -name "*.qcow2"` con fecha y tamaño | 8 CHR | 8 discos activos en la raíz del proyecto; ver 1.2 |
| Snapshots GNS3 | `ls -l snapshots/` | Los 8 de la sección 1.2 | Los 8 presentes; ver 1.2 |
| GNS3 | `gns3 …/failover_F2.gns3` | Servidor local en el puerto 3080 | **Falla:** "GNS3 is already running pid: 5578". El PID 5578 no existe y nada escucha en 3080. `~/.config/GNS3/2.2/gns3_server.pid` es del 25/10 15:46, el reinicio en frío: es un **archivo de PID huérfano**. **Resuelto** el 29/10 a las 16:20 UTC, con autorización de R5: se renombró a `gns3_server.pid.stale-20261025` (no se borró). GNS3 abrió `failover_F2.gns3` con el servidor local |
| Arranque de nodos | `start <nodo>` en la consola de gestión de GNS3, de a uno, cada 20–25 s | 8 CHR, PC-USER y SRV | 29/10 16:25–16:31 UTC: 8 CHR arrancados y enlaces en verde. EDGE muestra `MikroTik 7.16 (stable)`. PC-USER levantó con `192.168.10.100/24`. **SRV:** GNS3 respondió "Cannot console to SRV" (a revisar). Host Windows con **359 MB de RAM libres** con todo encendido; la CPU de la VM, ~57 % |
| Versión e identidad | `:put [/system resource get version]`, `/system identity print` (7 routers) | 7.16 e identidad correcta | **Cumple:** los 7 con `7.16 (stable)` e identidad igual al nombre |
| eBGP | EDGE: `/routing bgp session print`; ISP: `count-only where established` | 2 `established` | **Cumple:** `ebgp-isp1-1` y `ebgp-isp2-1` `established`, hold-time 3m, keepalive 1m, 2 prefijos recibidos cada una (16:38 UTC). ISP-1 e ISP-2: 1 cada uno |
| Rutas BGP | EDGE: `/ip route print where (dst-address=0.0.0.0/0 or bgp)`; ISP: `where bgp` | Default vía ISP-1 (y vía ISP-2 de respaldo), `.1/32` y `.2/32` | **Cumple:** default activo vía `10.255.0.1` y de respaldo vía `10.255.0.5`; `10.255.255.1/32` vía ISP-1 y `.2/32` vía ISP-2. Cada ISP recibe solo `192.168.10.0/24` y `192.168.20.0/24` |
| OSPF | `/routing ospf neighbor print terse` (EDGE y CORE) y `count-only where state=Full` (DIST) | 4 `Full` cada CORE (7 en total) | **Cumple:** EDGE 2, CORE-1 4, CORE-2 4, DIST-1 2, DIST-2 2; las 7 adyacencias en `Full` |
| LSA externos y default interno | `/routing ospf lsa print count-only where type=external`; `/ip route print where dst-address=0.0.0.0/0` | 3 | **Cumple:** 3 en EDGE, CORE-1, CORE-2, DIST-1 y DIST-2. Los CORE tienen el default OSPF vía EDGE (distancia 110) |
| VRRP | DIST-1 y DIST-2: `/interface vrrp print` | USERS master DIST-1; SERVERS master DIST-2 | **Cumple:** DIST-1 `vrrp-users-10` RM (150) y `vrrp-servers-20` B (100); DIST-2 `vrrp-servers-20` RM (150) y `vrrp-users-10` B (100). VRRPv2, intervalo 1 s |
| Firewall | EDGE: `:put [/ip firewall filter print count-only]` | 15 | **Cumple:** 15 |
| SSH-MGMT | `/ip service print where name=ssh` (7 routers) | Solo VRF `MGMT` y `172.31.250.10/32` | **Cumple** en los 7 |
| Hosts | PC-USER: `ping … -c 3` | 3/3 | **Cumple desde PC-USER:** 3/3 a `10.255.255.1` (TTL 61), `10.255.255.2` (TTL 61) y SRV `192.168.20.100` (TTL 63); latencias de 90 a 585 ms. **Desde SRV, pendiente:** GNS3 no abre su consola ("Cannot console to SRV"), aunque SRV responde |
| Opciones de `ping` en VPCS | `ping ?` | Que exista `-t` | **Cumple:** VPCS 0.8.5 admite `-t` (hasta Ctrl+C), `-i ms` y `-w ms` |
| Relojes | `/system clock` de cada router y `date -u` en la VM | Desfase relevado | Los routers están en UTC (`gmt-offset +00:00`), sin NTP, y en minutos coinciden con la VM (EDGE 16:38:39, ISP-1 16:39:37, ISP-2 16:40:02, CORE-1 16:40:29, CORE-2 16:40:54, DIST-1 16:41:21, DIST-2 16:41:47, leídos en ese orden). **El desfase al segundo se mide justo antes de cada drill** (sección 5) |
| Carga con todo encendido | `uptime`, `free -m` | ≤ ~12 | 16:44 UTC: carga 10,53 / 11,37 / 8,18; 1090 MB disponibles; swap sin uso; host Windows con 647 MB libres |
| Arranque de los routers | Log de EDGE | — | EDGE registró `router was rebooted without proper shutdown` el 29/10 a las 16:27:02, al arrancar hoy (también el 25/10 a las 14:18 y 15:54). La causa de este registro no se determinó; puede corresponder al apagado previo de la VM con los nodos encendidos, pero no se comprobó |

**Resultado:** la línea base de F3 se conserva: BGP, OSPF, LSA externos, VRRP, firewall y SSH-MGMT coinciden con el cierre del 25/10. Solo quedan pendientes los pings originados en SRV.

**Incidente durante la línea base (29/10, ~16:43 UTC):** Claude envió por error `clear ip` a la consola VPCS de PC-USER, lo que borró la IP de la memoria de ese host. Se restauró de inmediato, con los valores que mostró el host al arrancar (`ip 192.168.10.100 255.255.255.0 192.168.10.1`), y se verificó con `show ip` y `ping 10.255.255.1 -c 3` (3/3). No se ejecutó `save`, así que su archivo de arranque no cambió. No afectó a ningún router.

No se repiten las pruebas de F3: solo esta línea base.

---

## 2. Snapshots y respaldos

### 2.1 Respaldos privados de F3 (verificados el 29/10)

- **Ubicación:** carpeta privada local de R5, `respaldos_F3_privado/`, con dos juegos independientes: `juego_principal/` y `copia_verificacion/`.
- **Contenido:** 16 archivos por juego: 7 exports originales, 7 backups binarios `aes-sha256`, y el export y el backup de EDGE previos al firewall.
- **Integridad:** `sha512sum -c SHA512SUMS_F3_20261025.txt` dio **16/16 OK en cada juego**. Los hashes coinciden con el inventario y con la memoria 6.2. No se abrió ni se mostró el contenido de ningún archivo.
- **Restore:** no se probó ninguno.

### 2.2 Dependencia pendiente: transferencia a R1

Los 16 archivos siguen bajo custodia exclusiva de R5. Los `.rsc` originales tienen las claves OSPF en claro.

Método propuesto:
1. **Empaquetar:** un único archivo `7z` con AES-256 y nombres de archivo cifrados (`7z a -t7z -mhe=on -p F3_respaldos_privados.7z respaldos_F3_privado/juego_principal SHA512SUMS_F3_20261025.txt`), o `age -p`. La passphrase la genera R5 y **se pasa por un canal distinto** del archivo (en persona o por llamada), nunca por el mismo chat ni por correo.
2. **Transferir:** el archivo cifrado, por un enlace privado con acceso restringido a la cuenta de R1, o en mano.
3. **Verificar:** R1 descomprime, corre `sha512sum -c` (16/16) y confirma por escrito, indicando el SHA-256 del `.7z` recibido.
4. **Custodia:** R5 conserva sus copias hasta esa confirmación y después acuerda con R1 si las mantiene.

> **Bloqueante administrativo**, no técnico: hasta que R1 confirme la recepción, F3 sigue con una sola custodia.

### 2.3 Snapshot `PRE_F4` (propuesto)

- **Nombre:** `PRE_F4_R5_<AAAA-MM-DD>`, creado en GNS3 **con los nodos detenidos**, como en F3.
- **Antes de crearlo:** la línea base en vivo debe estar aprobada, y hay que comprobar el espacio libre dentro de la VM y en el host.
- **Riesgo:** el host tiene 11 GB libres y el disco diferencial de la VM crece con cada snapshot GNS3. Hay que medir el tamaño de los snapshots de F3 antes de sumar el de F4.

### 2.4 Estrategia `pre-drillN` / `post-drillN`

| Juego | Routers | Contenido | Dónde queda |
| --- | --- | --- | --- |
| `pre-f4` (inicial) | Los 7 | Export y backup `aes-sha256` | En el router; se trasladan al cierre de F4 |
| `pre-drillN` / `post-drillN` | Solo los afectados: D1 EDGE e ISP-1 · D2 EDGE e ISP-2 · D3 CORE-1 · D4 y D5 DIST-1 y DIST-2 | Export y backup | En el router |
| `pre-secN` / `post-secN` | S1 DIST-2 · S2 EDGE · S3 DIST-2 | Export y backup | En el router |
| `post-f4` (cierre) | Los 7 | Export y backup | Se trasladan con los anteriores |

- **Nombres:** `<router>_<AAAA-MM-DD>_<hito>`, según la política 1.4.
- **Traslado:** una sola vez al final, por Base64 en la consola, dos veces por separado, con SHA-512 de cada copia (el mismo método que F3). Así no se hacen decenas de traslados lentos en medio de los drills.
- **Publicación:** exports saneados de los routers afectados por cada drill, por PR de su dueño. Lo decide R1 (sección 9).

---

## 3. Matriz de los cinco drills

Contraste con el repositorio:
- `backlog.md` (Epic F4) pide runbook, backups pre y post, tiempo de reconvergencia y post-mortem por drill, pero **no fija los escenarios**. La memoria 4.2 tampoco. La propuesta de R1 cubre los tres mecanismos redundantes del diseño: multi-homing BGP, ECMP/OSPF en el core y VRRP.
- **Fuera de alcance:** EDGE es un punto único de falla por diseño (no tiene par). Su caída no tiene continuidad que demostrar y no se propone como drill.

| Drill | Falla | Acción recomendada | Detección prevista | Qué se mide | Debe mantenerse | Runbook |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | Enlace ISP-1 ↔ EDGE | *Suspend* del enlace en GNS3 | Hold-time BGP (~180 s) | Pérdida hacia el default hasta que pasa a ISP-2 | OSPF, VRRP, LAN ↔ LAN | `D1_caida_ISP-1.md` |
| D2 | Enlace ISP-2 ↔ EDGE | *Suspend* del enlace | Hold-time BGP (~180 s) | 0 pérdidas hacia ISP-1; retiro de `.2/32` | El default vía ISP-1 | `D2_caida_ISP-2.md` |
| D3 | CORE-1 | *Suspend* de sus 4 enlaces de producción (alternativas: detener el nodo o `disable`) | Dead-interval OSPF (40 s) | Pérdida parcial de los flujos ECMP vía CORE-1 | BGP, VRRP, gestión | `D3_caida_CORE-1.md` |
| D4 | Master VRRP de USERS (DIST-1) | `disable ether3` en DIST-1 | Intervalo de caída VRRP (~3,6 s teórico) | Failover y failback del gateway `.10.1` | SERVERS, OSPF y BGP | `D4_failover_VRRP_USERS.md` |
| D5 | Master VRRP de SERVERS (DIST-2) | `disable ether4` en DIST-2 | Ídem | Failover y failback del gateway `.20.1` | USERS, OSPF y BGP | `D5_failover_VRRP_SERVERS.md` |

**Observaciones de diseño:**
- **GNS3 no baja la portadora** del lado vecino cuando se suspende un enlace o se apaga un nodo. Por eso D1 a D3 se detectan por timers de protocolo, no por un cambio de estado de la interfaz.
- En D4 y D5 se recomienda `disable` en el DIST y no *Suspend*. Con *Suspend*, el DIST seguiría anunciando su LAN por OSPF y se perdería tráfico de retorno.
- **D2 no tiene impacto sobre el default.** Su valor es comprobar que la caída del proveedor de respaldo no afecta el servicio. Si R1 quiere más exigencia, una variante es repetir D2 con el default ya en ISP-2 (D1 en curso). No se recomienda: son dos fallas a la vez.
- No se cambian timers (hold-time, dead-interval) ni se agrega BFD. Los tiempos medidos reflejan la configuración aprobada.

---

## 4. Ejecución: orden, condiciones y umbral de aborto

- **Orden propuesto:** D4 → D5 → D3 → D1 → D2. Primero los de menor impacto y duración, para validar el método de medición. Cada drill necesita autorización individual de R1.
- **Entre drills:** la línea base completa tiene que volver antes de seguir.
- **Umbral de aborto de la VM:** se aborta y se revierte si la carga de 1 minuto supera en más de 4 la carga medida en reposo durante 5 minutos, si `free -m` muestra swap en crecimiento sostenido, o si una consola deja de responder más de 60 s. El umbral exacto se fija con la línea base en vivo.

---

## 5. Estrategia de medición temporal

**Problema:** los 7 routers, MGMT-CLIENT, la VM y Windows tienen relojes independientes, sin NTP (los exports no tienen `/system ntp`). Bajo TCG, los relojes de los CHR pueden derivar.

**Estrategia:**
1. **Métrica principal, independiente de los relojes:** la interrupción de servicio. Se mide con `ping <destino> -t` desde los VPCS (PC-USER y SRV), una sonda por segundo. Interrupción = `icmp_seq` faltantes × intervalo. VPCS 0.8.5 admite `-t` (verificado el 29/10).
2. **Tiempos de protocolo dentro de un mismo router:** se calculan diferencias entre eventos del log de un mismo equipo (por ejemplo, en EDGE, `HoldTimer expired` → cambio de default activo). No se mezclan relojes.
3. **Marcador T0 en el router donde se actúa:** `:log info "F4-Dn T0"` en el mismo comando que la acción, cuando la acción es por consola. Con *Suspend* en GNS3, T0 es la hora de la VM.
4. **Desfase entre relojes:** inmediatamente antes de cada drill se corre `/system clock print` en los routers involucrados y `date -u` en la VM, y se registran las diferencias. Bajo TCG, la incertidumbre esperable es de ±2 s; se informa junto con cada tiempo entre equipos distintos.
5. **Con monitoreo opción A (sección 6):** el recolector (MGMT-CLIENT) registra todo con **un único reloj**, lo que reemplaza a los puntos 3 y 4.

**Definiciones por drill:**
- T0, falla;
- T1, detección del protocolo;
- T2, primer eco restablecido;
- T3, convergencia del plano de control;
- T4, reversión;
- T5, vuelta a la línea base.

Se reportan detección (T1 − T0), interrupción (por sondas), convergencia (T3 − T0) y failback (T5 − T4), con la carga de la VM en cada momento.

> **Limitación declarada:** con TCG, los tiempos están inflados respecto de un equipo real. Se reportan como medidos **en este entorno emulado**.

### Plantilla común de post-mortem

1. Resumen del drill y resultado (éxito o fracaso).
2. Línea de tiempo T0–T5, con el reloj de origen de cada marca.
3. Métricas: detección, interrupción (sondas perdidas), convergencia y failback; carga de la VM.
4. Comparación con lo esperado por diseño (timers).
5. Qué funcionó y qué no.
6. Causa raíz de cada desvío, sin atribuir causas no demostradas.
7. Acciones correctivas, con responsable y fecha.
8. Evidencias y respaldos asociados (nombres y SHA-512).

Al final de los cinco drills: **post-mortem global** con la tabla comparativa y las lecciones aprendidas.

---

## 6. Propuesta de monitoreo

Datos del entorno que condicionan las opciones:
- **MGMT-CLIENT es un CHR RouterOS**, no un Linux (prompt `[admin@MGMT-CLIENT]` en la evidencia F3-17).
- Es el único origen autorizado en `172.31.250.0/28`.
- Las reglas de gestión de los 7 routers aceptan **solo ICMP y SSH** desde `.10`.
- El usuario `monitor` existe en los 7 routers (grupo `monitor`: `ssh,read`, `!sensitive`).

| Criterio | A. Chequeos por SSH de solo lectura | B. SNMPv3 de solo lectura |
| --- | --- | --- |
| **Qué se monitorea en cada router** | Lo que muestra un `print` con política `read`: interfaces (`running`), sesiones BGP (`/routing bgp session print count-only where established`), vecinos OSPF en `Full`, LSA externos, estado VRRP, cantidad de reglas y contadores del firewall, CPU, memoria y uptime | MIB estándar: IF-MIB (interfaces) y HOST-RESOURCES (CPU, memoria). **No está confirmado** que RouterOS 7.16 exponga por SNMP el estado de los vecinos OSPF, de las sesiones BGP ni de VRRP; habría que comprobarlo con `snmpwalk` antes de adoptar esta opción |
| **Recolector** | MGMT-CLIENT: un script RouterOS con `/system ssh-exec` hacia cada router, ejecutado por `/system scheduler`, que guarda resultados con `:log` | Hace falta un cliente SNMP: no está confirmado que `/tool snmp-get` de RouterOS soporte v3. Si no lo soporta, habría que agregar un nodo Linux en MGMT, con más RAM sobre un host ya al límite |
| **Enlaces** | Ojo: en GNS3 una falla simulada no cambia `running`. Se detecta por protocolo, no por interfaz | Ídem: `ifOperStatus` no cambia en GNS3 |
| **BGP, OSPF y VRRP** | Sí, con contadores `count-only` y estados `print` | Incierto (ver arriba) |
| **Tiempos** | Un único reloj, el de MGMT-CLIENT. Resolución = período de sondeo | Un único reloj, el del recolector |
| **Consumo y riesgos para la VM** | Cada `ssh-exec` hace un intercambio de claves, costoso bajo TCG. Propuesta: cada 60 s a los 7 routers en reposo y cada 5 s solo a los 1–2 routers del drill. Medir la carga 10 min antes y después de habilitarlo | Sondeo UDP liviano por router, pero un posible nodo Linux extra consumiría cientos de MB de RAM |
| **Configuración adicional** | En los 7 routers: importar la clave pública SSH de MGMT-CLIENT para el usuario `monitor` (`/user ssh-keys import`). En MGMT-CLIENT: generar el par de claves, el script y el scheduler. **No hace falta tocar el firewall ni los servicios** | En los 7 routers: `/snmp` habilitado con `vrf=MGMT`, una comunidad v3 con `authPriv`, solo lectura y origen `172.31.250.10/32`; regla `accept udp/161` en la cadena de gestión antes del `drop`; credenciales SNMPv3 nuevas que custodiar |
| **Reversión** | Quitar la clave de `monitor` y el scheduler de MGMT-CLIENT | Deshabilitar SNMP, quitar la comunidad y la regla de firewall |

**Recomendación: opción A.**
- Usa servicios y reglas ya vigentes.
- Agrega un solo tipo de cambio por router: una clave pública para un usuario de solo lectura.
- No crea secretos compartidos nuevos: la clave privada no sale de MGMT-CLIENT.
- Da un reloj único para los tiempos de los drills.

**Antes de habilitarla, verificar** en un solo router y con autorización de R1:
- que `ssh-exec` funciona con `strong-crypto=yes` y con el tipo de clave elegido;
- que el grupo `monitor` alcanza para los comandos;
- que ninguna salida muestra claves.

`/routing bgp connection print` queda excluido del script.

---

## 7. Recuperación sin perder F3

Orden de escalamiento ante un problema durante F4:
1. **Revertir la acción del drill:** *Resume*, `enable` o rearranque del nodo.
2. **Comparar con `pre-drillN`:** si la configuración del router afectado cambió, recargar su backup `pre-drillN` (`/system backup load`), solo con autorización de R1. El restore de backups de F3 nunca se probó, y en SSH-MGMT requirió ajustes manuales de interfaces: es un riesgo real.
3. **Último recurso, el snapshot GNS3 `PRE_F4`:** revierte los 8 CHR a la vez. Nunca se probó un restore de snapshot de GNS3. Requiere autorización de R1.
4. **Nunca** restaurar el snapshot de VirtualBox `Pre-Lab`.

> **Propuesta:** antes de D1, probar un restore de backup en un entorno aislado (por ejemplo, el `F3_ISP1_20261025.backup` en una copia del proyecto). Así se cubre también el pendiente de restore de F3. Hace falta decidir si alcanzan la RAM y el disco.

---

## 8. Riesgos y bloqueantes

| # | Riesgo o bloqueante | Impacto | Mitigación propuesta |
| --- | --- | --- | --- |
| 1 | **Recursos del host:** ~1 GB de RAM libre con la VM apagada; 12 vCPU asignadas sobre 12 hilos; TCG | Cuelgues (como el del 25/10), pérdida de caracteres al tipear, tiempos inflados | Cerrar otras aplicaciones en Windows; umbral de aborto; comandos cortos. Que R1 decida si se bajan las vCPU de la VM (cambio de hipervisor, requiere autorización) |
| 2 | **Disco del host al 96 %** (11 GB libres) | Un snapshot GNS3 o el crecimiento del disco diferencial pueden llenar `C:` y corromper la VM | Medir antes de `PRE_F4`; liberar espacio en Windows antes de empezar |
| 3 | El snapshot de VirtualBox `Pre-Lab` es anterior al laboratorio | Restaurarlo por error borra F3 | Prohibición explícita (sección 7) |
| 4 | **Restore nunca probado** en F2 ni F3 | La recuperación del paso 2 o 3 podría fallar | Prueba aislada antes de D1 (sección 7) |
| 5 | **Claves aprobadas visibles en `docs/memoria.md`** (secciones 1.2 y 1.3, desde F0) | Contradice la regla de no exponerlas en GitHub; ya son públicas | Decisión de R1 (sección 9). No se cambian claves en F4 |
| 6 | Las pruebas S1 a S3 exigen tipear la clave aprobada para restaurar | Que quede expuesta a Claude si el uso de computadora está activo | Pausar el uso de computadora durante la restauración y limpiar la pantalla después |
| 7 | 16 respaldos de F3 con una sola custodia; `.rsc` con claves OSPF en claro en una carpeta local sin permisos restringidos | Pérdida o filtración | Transferencia cifrada a R1 (sección 2.2) |
| 8 | Las consolas de GNS3 aceptan un solo cliente y cambian de puerto al reiniciar | Interrumpe la observación en paralelo | Abrir y comprobar las consolas antes de T0 |
| 9 | Monitoreo A sin probar (`ssh-exec`, tipo de clave) | Podría no funcionar como se espera | Prueba en un solo router antes de desplegarlo |
| **B1** (resuelto) | El servidor local de GNS3 no arrancaba por un `gns3_server.pid` huérfano del reinicio en frío del 25/10 | Bloqueaba la línea base y cualquier drill | Resuelto el 29/10 con autorización de R5: se renombró a `gns3_server.pid.stale-20261025` y se reabrió GNS3. Si la VM se vuelve a apagar con los nodos encendidos, el problema puede repetirse: detener los nodos y cerrar GNS3 antes de apagarla |
| 12 | La ventana de GNS3 toma el foco y el texto tipeado puede caer en su consola de gestión o en la consola equivocada; ya pasó una vez (`clear ip` en PC-USER, revertido) | Durante un drill, un comando en la consola equivocada invalida la medición o cambia la configuración | Antes de cada comando de modificación, verificar en pantalla la pestaña activa y el prompt; comandos de una línea; no usar comandos genéricos (`clear`) en VPCS |
| 13 | SRV no abre consola desde GNS3, aunque responde a ping | Sin consola de SRV no se pueden originar sondas desde SERVERS (D5) | Revisar el puerto de consola de SRV en GNS3 antes de D5 |
| 14 | Con todo encendido, el host Windows queda con 360–650 MB libres y la VM con ~1,1 GB disponibles y carga ~11 | Riesgo de cuelgue como el del 25/10 | Cerrar otras aplicaciones en Windows; umbral de aborto (sección 4) |
| 10 | Copia anidada `failover_F3/` con discos del 19/10 | Abrirla por error mostraría un estado anterior a F3, y operar sobre ella daría resultados falsos | Abrir siempre `failover_F2.gns3` de la raíz del proyecto; que R1 decida si se archiva o se elimina la copia después de F4 |
| 11 | El pegado por portapapeles no llega a la VM y el teclado de la VM es latinoamericano | Comandos mal escritos | Se escribe con scancodes de VirtualBox mapeados al teclado latinoamericano; cada comando se verifica en pantalla antes de dar Enter cuando no es de solo lectura |

---

## 9. Decisiones pendientes de R1

1. Aprobar o ajustar los cinco escenarios y el orden D4 → D5 → D3 → D1 → D2.
2. Acción de D3: *Suspend* de 4 enlaces (con o sin la API de GNS3), detener el nodo o `disable`.
3. Acción de D4/D5: `disable` de la interfaz LAN (recomendada) o *Suspend*.
4. Monitoreo: aprobar la opción A y su prueba en un router.
5. Alcance de los backups por drill (solo los routers afectados) y si se publican exports saneados por drill.
6. Si se hace una prueba de restore aislada antes de D1, y con qué backup.
7. Ajuste de recursos de la VM (vCPU) o no.
8. Qué hacer con las claves de laboratorio publicadas en la memoria 1.2/1.3.
9. Fecha y método de la transferencia de los 16 respaldos de F3.
10. Autorización individual de S1, S2 y S3, con el alcance propuesto (CORE-2–DIST-2, `ebgp-isp2` y VRID 10 en DIST-2).

---

## 10. Archivos preparados (sin publicar)

| Archivo | Contenido |
| --- | --- |
| `runbooks/F4/F4_00_PLAN_Y_PREFLIGHT_R5.md` | Este informe |
| `runbooks/F4/D1_caida_ISP-1.md` | Drill 1 |
| `runbooks/F4/D2_caida_ISP-2.md` | Drill 2 |
| `runbooks/F4/D3_caida_CORE-1.md` | Drill 3 |
| `runbooks/F4/D4_failover_VRRP_USERS.md` | Drill 4 |
| `runbooks/F4/D5_failover_VRRP_SERVERS.md` | Drill 5 |
| `runbooks/F4/S1_R3_OSPF_MD5_clave_incorrecta.md` | Prueba de seguridad OSPF (R3) |
| `runbooks/F4/S2_R1_BGP_TCP-MD5_clave_incorrecta.md` | Prueba de seguridad BGP (R1) |
| `runbooks/F4/S3_R4_VRRP_clave_incorrecta.md` | Prueba de seguridad VRRP (R4) |

Ninguno contiene claves, contraseñas, contenido de respaldos ni localizadores privados sensibles.

**Siguiente paso:** completar la sección 1.3 en vivo, en modo solo lectura, y entregar a R1 para su revisión. No se avanza sin su aprobación.
