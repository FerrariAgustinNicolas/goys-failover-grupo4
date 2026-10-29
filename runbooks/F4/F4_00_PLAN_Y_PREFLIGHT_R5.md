# F4_00 — Plan y preflight de F4 (R5)

**Fecha:** 29/10/2026 · **Preparó:** R5 (Lorenzo Bellomo), con asistencia de Claude · **Revisa:** R1.
**Ubicación:** rama `docs/f4-r5-preflight`, publicada en GitHub (base `main` = `a423e04`, merge de la PR #32), carpeta `runbooks/F4/`. El primer commit es `c00d31b` (checkpoint inicial). Las correcciones pedidas por R1 van en commits posteriores de la misma rama. No hay PR y `main` no se tocó.
**Alcance autorizado:** planificación aprobada por R1 el 29/10, con correcciones (sección 9). No se ejecutó ningún drill (D1 a D5) ni ninguna prueba de seguridad (S1 a S3); cada uno requiere una nueva autorización individual de R1.

> **Estado:**
> - La línea base en vivo (sección 1.3) se completó el 29/10 entre las 15:07 y las 16:44 UTC, en modo solo lectura.
> - Siguen pendientes los pings originados en SRV.
> - El bloqueante B1 (PID huérfano de GNS3) se resolvió.
> - Hubo una modificación accidental en PC-USER, revertida (1.3).
> - **La VM volvió a congelarse el 29/10 hacia las 16:57 UTC** (riesgo 15, sección 8).

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

**Modificación accidental revertida durante la línea base (29/10, ~16:43 UTC):** Claude envió por error `clear ip` a la consola VPCS de PC-USER, lo que borró la IP de la memoria de ese host. Se restauró de inmediato, con los valores que mostró el host al arrancar (`ip 192.168.10.100 255.255.255.0 192.168.10.1`), y se verificó con `show ip` y `ping 10.255.255.1 -c 3` (3/3). No se ejecutó `save`, así que su archivo de arranque no cambió. No afectó a ningún router.

No se repiten las pruebas de F3: solo esta línea base.

---

## 2. Snapshots y respaldos

### 2.1 Respaldos privados de F3 (verificados el 29/10)

- **Ubicación:** carpeta privada local de R5, `respaldos_F3_privado/`, con dos juegos independientes: `juego_principal/` y `copia_verificacion/`.
- **Contenido:** 16 archivos por juego: 7 exports originales, 7 backups binarios `aes-sha256`, y el export y el backup de EDGE previos al firewall.
- **Integridad:** `sha512sum -c SHA512SUMS_F3_20261025.txt` dio **16/16 OK en cada juego**. Los hashes coinciden con el inventario y con la memoria 6.2. No se abrió ni se mostró el contenido de ningún archivo.
- **Restore:** no se probó ninguno.

### 2.2 Transferencia a R1 (aprobada; condición previa de D4)

Los 16 archivos siguen bajo custodia exclusiva de R5. Los `.rsc` originales tienen las claves OSPF en claro.

Método aprobado por R1:
1. **Empaquetar:** un único archivo `7z` con AES-256 y nombres de archivo cifrados (`-mhe=on`). R5 crea el archivo e ingresa la contraseña de forma local; Claude no la ve. La contraseña se pasa a R1 **por un canal independiente** del archivo, nunca por el mismo chat ni por correo.
2. **Transferir:** el `.7z`, por un enlace privado restringido a la cuenta de R1, o en mano.
3. **Verificar:** R1 descomprime, corre `sha512sum -c SHA512SUMS_F3_20261025.txt` (16/16) y confirma por escrito.
4. **Custodia:** R5 conserva sus dos copias hasta esa confirmación.

> **Debe completarse, con 16/16 SHA-512 confirmados por R1, antes de ejecutar D4.**

### 2.3 Snapshot `PRE_F4`

- **Nombre:** `PRE_F4_R5_<AAAA-MM-DD>`, creado en GNS3 **con los nodos detenidos**, como en F3.
- **Condición de R1:** tener **al menos 20 GB libres en el disco del host** antes de generar snapshots nuevos. El 29/10 había 11 GB. Cada snapshot de F3 ocupa 342 MB dentro de la VM, pero el disco diferencial de la VM crece en el host.
- No se eliminan snapshots históricos.

### 2.4 Respaldos de F4 (aprobados por R1)

| Juego | Routers | Contenido | Traslado y verificación |
| --- | --- | --- | --- |
| `pre-f4` (inicial) | Los 7 | Export original y backup `aes-sha256` | Fuera de los routers y verificado antes de D4 |
| `pre-drillN` / `post-drillN` | Los afectados: D4 y D5 DIST-1 y DIST-2 · D3 CORE-1 · D1 EDGE e ISP-1 · D2 EDGE e ISP-2 | Ídem | **Fuera de los routers y verificado antes de empezar el drill siguiente** |
| `pre-secN` / `post-secN` | S1 CORE-2 · S2 EDGE · S3 DIST-2 | Ídem | Ídem, antes de la prueba siguiente |
| `post-f4` (final) | Los 7 | Ídem | Al cierre de **todos** los drills y pruebas de seguridad |

- **Nombres:** `<router>_<AAAA-MM-DD>_<hito>`, según la política 1.4.
- **Traslado:** por Base64 en la consola, dos veces por separado, con SHA-512 de cada copia (el método de F3). No se depende de un traslado único al final de F4.
- **Custodia:** originales y binarios son privados, con SHA-512, fuera del repositorio.
- **Publicación:** después de la auditoría de R1, los exports saneados de los routers afectados se publican **agrupados por responsable**, junto con la documentación de F4. No hay una PR por drill.

---

## 3. Matriz de los cinco drills

Contraste con el repositorio:
- `backlog.md` (Epic F4) pide runbook, backups pre y post, tiempo de reconvergencia y post-mortem por drill, pero **no fija los escenarios**. La memoria 4.2 tampoco. La propuesta de R1 cubre los tres mecanismos redundantes del diseño: multi-homing BGP, ECMP/OSPF en el core y VRRP.
- **Fuera de alcance:** EDGE es un punto único de falla por diseño (no tiene par). Su caída no tiene continuidad que demostrar y no se propone como drill.

Escenarios, orden y métodos **aprobados por R1 el 29/10**. Orden de ejecución: **D4 → D5 → D3 → D1 → D2**.

| Orden | Drill | Falla | Método aprobado | Detección prevista | Qué se mide | Runbook |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | D4 | Master VRRP de USERS (DIST-1) | `disable ether3` en DIST-1; el resto de las interfaces, sin cambios | Intervalo de caída VRRP (~3,6 s teórico) | Failover y failback del gateway `.10.1` | `D4_failover_VRRP_USERS.md` |
| 2 | D5 | Master VRRP de SERVERS (DIST-2) | `disable ether4` en DIST-2; ídem | Ídem | Failover y failback del gateway `.20.1` | `D5_failover_VRRP_SERVERS.md` |
| 3 | D3 | CORE-1 | `disable ether1,ether2,ether3,ether4` en una única ejecución validada; `ether5` (MGMT) sin tocar | Dead-interval OSPF (40 s) | Pérdida parcial de los flujos ECMP vía CORE-1 | `D3_caida_CORE-1.md` |
| 4 | D1 | Enlace ISP-1 ↔ EDGE | *Suspend* en GNS3, sin cambios de configuración | Hold-time BGP (180 s) | Detección y **cambio de la ruta default activa en EDGE** | `D1_caida_ISP-1.md` |
| 5 | D2 | Enlace ISP-2 ↔ EDGE | *Suspend* en GNS3, sin cambios de configuración | Hold-time BGP (180 s) | 0 pérdidas hacia ISP-1; retiro de `.2/32` | `D2_caida_ISP-2.md` |

**Observaciones de diseño:**
- **GNS3 puede mantener activa la interfaz virtual** aunque se suspenda el enlace o se deshabilite la interfaz del otro extremo. Por eso, en D1 a D3, los vecinos detectan la falla por el protocolo (BGP u OSPF) y no por un cambio de estado de la interfaz.
- **D1 no mide la "recuperación de Internet":** no hay un servicio externo común detrás de los dos ISP. La evidencia es el cambio de la ruta activa en EDGE.
- **D2 no tiene impacto sobre el default.** Su valor es comprobar que la caída del proveedor de respaldo no afecta la salida activa.
- No se cambian timers (hold-time, dead-interval) ni se agrega BFD.

---

## 4. Ejecución: orden, condiciones y umbral de aborto

- **Orden aprobado:** D4 → D5 → D3 → D1 → D2. Cada drill necesita autorización individual de R1.
- **Entre drills:** la línea base completa tiene que volver, y los respaldos del drill tienen que estar trasladados y verificados, antes de seguir.
- **Recursos (condición de R1):**
  - no se reducen las 12 vCPU;
  - primero se cierran procesos innecesarios en Windows, se libera disco (meta: **≥ 20 GB libres antes de snapshots nuevos**) y se vuelve a medir con la topología funcionando;
  - si el host sigue con muy poca RAM libre o la VM se congela, **se detiene la preparación de pruebas cronometradas**.
- **Umbral de aborto durante un drill:**
  - la carga de 1 minuto de la VM supera en más de 4 la medida en reposo con la topología encendida;
  - `free -m` muestra swap en crecimiento sostenido;
  - una consola deja de responder más de 60 s;
  - el reloj de la VM se detiene.
- Las pérdidas de paquetes **no se atribuyen** a la saturación sin evidencia.

---

## 5. Estrategia de medición temporal

**Problema:** los 7 routers, MGMT-CLIENT, la VM y Windows tienen relojes independientes, sin NTP (los exports no tienen `/system ntp`). Bajo TCG, los relojes de los CHR pueden derivar.

**Estrategia:**
1. **Pérdida de sondas (independiente de los relojes):** `ping <destino> -t` desde los VPCS (PC-USER y SRV); VPCS 0.8.5 admite `-t`, verificado el 29/10. **No se presupone que salga exactamente una sonda por segundo.** Antes de cada drill se calibra:
   - se corre `ping -t` durante un período medido con el reloj de la VM (`date -u` al inicio y al final);
   - se calcula el intervalo efectivo como el tiempo transcurrido dividido por las sondas enviadas.
   La interrupción se informa como sondas faltantes × intervalo efectivo, con ese intervalo explícito.
2. **Tiempos de protocolo dentro de un mismo router:** se calculan diferencias entre eventos del log de un mismo equipo (por ejemplo, en EDGE, `HoldTimer expired` → cambio de default activo). No se mezclan relojes.
3. **Marcador T0 en el router donde se actúa:** `:log info "F4-Dn T0"` en el mismo comando que la acción (D3, D4 y D5). Con *Suspend* en GNS3 (D1 y D2), T0 es la hora de la VM.
4. **Desfase entre relojes (se mide, no se presupone):** inmediatamente antes de cada drill se corre `/system clock print` en los routers involucrados y `date -u` en la VM, y se registran las diferencias observadas. **No se asume ningún valor de incertidumbre**: se informa el medido. Si no se puede medir con confianza, los tiempos entre equipos distintos se informan como no comparables.
5. **El monitoreo por SSH no reemplaza los pings continuos ni los logs** para medir conmutaciones rápidas como VRRP (indicación de R1). Su resolución está limitada por el período de sondeo.

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

## 6. Monitoreo

> **Decisión de R1 (29/10): se aprueba la opción A.** Por ahora solo se autoriza un **piloto controlado contra CORE-2**, previa verificación de acceso y de recursos. Sin schedulers periódicos y sin distribuir claves públicas a los otros seis routers hasta revisar el resultado. El análisis comparativo original sigue abajo.

### 6.1 Piloto SSH contra CORE-2 (preparado, no ejecutado)

**Condiciones previas:**
- VM estable, sin congelamientos;
- RAM del host por encima del margen acordado;
- R5 con sesión en MGMT-CLIENT y en CORE-2;
- carga de la VM medida durante 10 minutos en reposo, con la topología encendida.

**Qué debe confirmar:**
1. que `/system ssh-exec` funciona en RouterOS 7.16;
2. que el tráfico pasa por MGMT (VRF `MGMT`, origen `172.31.250.10`, destino `172.31.250.5`);
3. que la autenticación es por clave pública;
4. que el usuario es `monitor`, con sus permisos actuales (`ssh,read`, `!sensitive`);
5. que las salidas de los comandos no muestran datos sensibles;
6. el impacto real sobre la carga de la VM.

**Pasos propuestos:**

1. En MGMT-CLIENT, generar un par de claves exclusivo del piloto. El método exacto disponible en 7.16 se confirma en el momento; la clave privada no sale de MGMT-CLIENT.
2. Copiar a CORE-2 **solo la clave pública** e importarla para `monitor` con `/user ssh-keys import public-key-file=… user=monitor`.
3. En MGMT-CLIENT, ejecutar una sola vez y a mano, sin scheduler:
   - `/system ssh-exec address=172.31.250.5 user=monitor command=":put [/routing ospf neighbor print count-only where state=Full]"`;
   - lo mismo con `/interface print count-only where running` y `:put [/system resource get cpu-load]`.
4. Medir la carga de la VM (`uptime`) antes, durante (10 ejecuciones seguidas) y después.
5. **Reversión:** en CORE-2, `/user ssh-keys remove [find user=monitor]`; en MGMT-CLIENT, borrar el par de claves del piloto.

`/routing bgp connection print` queda excluido siempre.

### 6.2 Análisis de alternativas (checkpoint inicial)

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

### 7.1 Restore aislado de ISP-1 (aprobado para planificar)

- **Qué:** `F3_ISP1_20261025.backup` en un proyecto GNS3 **completamente aislado**, con un CHR RouterOS 7.16 nuevo y sin enlaces hacia el proyecto operativo.
- **Cuándo:** **antes de D4**, solo si el espacio y la memoria lo permiten sin riesgo para la instancia principal.
- **Prohibido:** restaurar snapshots o backups sobre el proyecto operativo `failover_F2.gns3`; abrir la copia anidada `failover_F3/`; restaurar el snapshot de VirtualBox `Pre-Lab`.
- **Viabilidad al 29/10: no se cumple.**
  - La instancia principal ya deja al host con 360–650 MB libres y la VM se congeló.
  - Un CHR adicional pide 256–512 MB más dentro de la VM.
  - El host tiene 11 GB libres, por debajo de los 20 GB pedidos por R1.
- **Opción para evaluar con R1:** hacer el restore con la topología principal **detenida** (nodos apagados y snapshot `PRE_F4` ya tomado), en un proyecto separado con un solo CHR, y volver a arrancar la principal después.

---

## 8. Riesgos y bloqueantes

| # | Riesgo o bloqueante | Impacto | Mitigación propuesta |
| --- | --- | --- | --- |
| 1 | **Recursos del host:** ~1 GB de RAM libre con la VM apagada; 12 vCPU asignadas sobre 12 hilos; TCG | Cuelgues, pérdida de caracteres al tipear, tiempos inflados | Condición de R1: no reducir las vCPU todavía; cerrar procesos de Windows y volver a medir (sección 4) |
| 2 | **Disco del host al 96 %** (11 GB libres) | Un snapshot GNS3 o el crecimiento del disco diferencial pueden llenar `C:` y corromper la VM | **≥ 20 GB libres antes de snapshots nuevos** (condición de R1) |
| 3 | El snapshot de VirtualBox `Pre-Lab` es anterior al laboratorio | Restaurarlo por error borra F3 | Prohibición explícita (sección 7) |
| 4 | **Restore nunca probado** en F2 ni F3 | La recuperación del paso 2 o 3 podría fallar | Restore aislado de ISP-1 antes de D4, si los recursos lo permiten (7.1) |
| 5 | Claves aprobadas documentadas en `docs/memoria.md` (1.2 y 1.3) desde F0 | Ya son públicas | Decisión de R1: se mantienen, son exclusivas del laboratorio, no se rotan en F4, no se reutilizan fuera y no se muestran en evidencias nuevas |
| 6 | Las pruebas S1 a S3 exigen tipear la clave aprobada para restaurar | Que quede expuesta a Claude si el uso de computadora está activo | Pausar el uso de computadora durante la restauración y limpiar la pantalla después |
| 7 | 16 respaldos de F3 con una sola custodia; `.rsc` con claves OSPF en claro en una carpeta local sin permisos restringidos | Pérdida o filtración | Transferencia cifrada a R1 (sección 2.2) |
| 8 | Las consolas de GNS3 aceptan un solo cliente y cambian de puerto al reiniciar | Interrumpe la observación en paralelo | Abrir y comprobar las consolas antes de T0 |
| 9 | Monitoreo A sin probar (`ssh-exec`, tipo de clave) | Podría no funcionar como se espera | Prueba en un solo router antes de desplegarlo |
| **B1** (resuelto) | El servidor local de GNS3 no arrancaba por un `gns3_server.pid` huérfano del reinicio en frío del 25/10 | Bloqueaba la línea base y cualquier drill | Resuelto el 29/10 con autorización de R5: se renombró a `gns3_server.pid.stale-20261025` y se reabrió GNS3. Si la VM se vuelve a apagar con los nodos encendidos, el problema puede repetirse: detener los nodos y cerrar GNS3 antes de apagarla |
| 15 | **La VM se congeló otra vez el 29/10, hacia las 16:57 UTC**, unos 13 min después de la línea base, con la topología encendida. Su reloj quedó detenido y no procesaba el teclado. Del lado de Windows, el proceso de la VM tenía 5,7 GB reservados y solo 37 MB residentes: su memoria estaba paginada a disco. Al momento del diagnóstico (17:39 UTC) el host tenía entre 562 MB y 2,1 GB libres. La relación entre la paginación y el congelamiento es una hipótesis, no una causa demostrada | Cualquier prueba cronometrada queda invalidada; reiniciar en frío puede volver a dejar archivos de PID huérfanos y mensajes de arranque crítico | **Se detiene la preparación de pruebas cronometradas** (condición de R1). No se reinició la VM: queda a decisión de R5 y R1. Antes de seguir, liberar RAM en Windows (por ejemplo, cerrar Chrome, que ocupa ~1,9 GB) y repetir la medición |
| 12 | La ventana de GNS3 toma el foco y el texto tipeado puede caer en su consola de gestión o en la consola equivocada. Ya pasó una vez: `clear ip` en PC-USER, una **modificación accidental revertida** | Durante un drill, un comando en la consola equivocada invalida la medición o cambia la configuración | Antes de cada comando de modificación, verificar en pantalla la pestaña activa y el prompt; comandos de una línea; no usar comandos genéricos (`clear`) en VPCS |
| 13 | SRV no abre consola desde GNS3, aunque responde a ping | Sin consola de SRV no se pueden originar sondas desde SERVERS (D5) | **Condición de R1:** resolverlo y confirmar los pings de línea base desde SRV antes de D5. El diagnóstico (ver la configuración de consola de SRV en el proyecto) quedó pendiente por el congelamiento de la VM |
| 14 | Con todo encendido, el host Windows queda con 360–650 MB libres y la VM con ~1,1 GB disponibles y carga ~11 | Riesgo de cuelgue como el del 25/10 | Cerrar otras aplicaciones en Windows; umbral de aborto (sección 4) |
| 10 | Copia anidada `failover_F3/` con discos del 19/10 | Abrirla por error mostraría un estado anterior a F3, y operar sobre ella daría resultados falsos | Abrir siempre `failover_F2.gns3` de la raíz del proyecto; que R1 decida si se archiva o se elimina la copia después de F4 |
| 11 | El pegado por portapapeles no llega a la VM y el teclado de la VM es latinoamericano | Comandos mal escritos | Se escribe con scancodes de VirtualBox mapeados al teclado latinoamericano; cada comando se verifica en pantalla antes de dar Enter cuando no es de solo lectura |

---

## 9. Decisiones de R1 (29/10)

| # | Tema | Decisión |
| --- | --- | --- |
| 1 | Drills y orden | Aprobados los cinco, en orden D4 → D5 → D3 → D1 → D2. Cada ejecución requiere autorización individual |
| 2 | Métodos | D4: `disable ether3` en DIST-1. D5: `disable ether4` en DIST-2. D3: `disable ether1`–`ether4` en CORE-1 en una ejecución validada, sin tocar `ether5`. D1 y D2: *Suspend* en GNS3 |
| 3 | Correcciones | D1 mide el cambio de ruta activa en EDGE. D3 queda después de D4 y D5. El juego final de F4 va al cierre de todo. El restore es antes de D4. Método temporal sin supuestos (sección 5) |
| 4 | Monitoreo | Opción A. Solo un piloto contra CORE-2, sin schedulers ni otras claves |
| 5 | Backups | `pre-f4` y `post-f4` de los 7; pre y post de los afectados por drill y por prueba; cada juego trasladado y verificado antes del paso siguiente. Publicación agrupada por responsable, sin PR por drill |
| 6 | Restore | ISP-1 de F3 en un proyecto aislado, antes de D4, si los recursos lo permiten |
| 7 | Recursos | No reducir vCPU; liberar RAM y disco (≥ 20 GB) y volver a medir; detener la preparación si hay congelamientos |
| 8 | Claves | Se mantienen las de F0, sin rotar ni mostrar en evidencias nuevas |
| 9 | Respaldos F3 | Transferencia por `7z` AES-256 con nombres cifrados y la contraseña por un canal independiente; 16/16 confirmado antes de D4 |
| 10 | S1 a S3 | Objetivos aprobados, sin ejecución. S1 pasa a CORE-2 `ether4`. S2 queda reservada a R1. S3 sin sostener el doble master |
| 11 | Incidencias | Consola de SRV antes de D5. No tocar `failover_F3/` ni `Pre-Lab` ni los snapshots históricos. `clear ip` registrado como modificación accidental revertida |

---

## 10. Plan preciso para D4 (primer drill, sin ejecutar)

**Condiciones previas, todas obligatorias:**
1. VM estable, sin congelamientos; RAM del host y carga de la VM dentro de los márgenes (sección 4).
2. Transferencia de los respaldos F3 a R1 con 16/16 confirmado (2.2).
3. Restore aislado de ISP-1 hecho, si R1 lo mantiene como condición y los recursos lo permiten (7.1).
4. ≥ 20 GB libres en el host y snapshot `PRE_F4` creado con los nodos detenidos (2.3).
5. Juego `pre-f4` de los 7 routers y `pre-drill4` de DIST-1 y DIST-2, trasladados y verificados con SHA-512 (2.4).
6. Línea base completa repetida ese día: BGP 2/2, 7 `Full`, 3 LSA externos, roles VRRP, 15 reglas y pings.
7. Autorización individual de R1 para D4.

**Secuencia el día del drill:**

| Paso | Dónde | Acción |
| --- | --- | --- |
| 1 | VM | `date -u`, `uptime`, `free -m` |
| 2 | DIST-1, DIST-2, CORE-1 | `/system clock print`, uno detrás de otro; registrar el desfase medido |
| 3 | PC-USER | Calibrar `ping 192.168.10.1 -t` durante un período medido con el reloj de la VM y calcular el intervalo efectivo |
| 4 | DIST-1 | Verificación previa de D4 (4.1): identidad, `vrrp-users-10` MASTER y `ether3` habilitada |
| 5 | DIST-2 | `/log print follow where topics~"vrrp"` |
| 6 | PC-USER | `ping 192.168.10.1 -t` en marcha |
| 7 | DIST-1 | **T0:** `:log info "F4-D4 T0"; /interface disable ether3`, verificando antes la pestaña y el prompt |
| 8 | DIST-2 / PC-USER | Observar el paso a MASTER (T1) y el fin de la racha de pérdidas (T2); luego CORE-1, sin nexthop DIST-1 hacia USERS (T3) |
| 9 | PC-USER | Segunda corrida: `ping 192.168.20.100 -t` |
| 10 | DIST-1 | **T4:** `:log info "F4-D4 T4"; /interface enable ether3` |
| 11 | Todos | Failback: DIST-1 vuelve a MASTER (T5); línea base completa |
| 12 | DIST-1 y DIST-2 | `post-drill4` (export y backup), traslado doble y SHA-512 |
| 13 | — | Post-mortem con la plantilla de la sección 5 |

**Aborto:** se revierte de inmediato (paso 10) si se cumple cualquiera de estas condiciones:
- se alcanza el umbral de la sección 4;
- cambia SERVERS (VRID 20);
- cae una adyacencia OSPF o una sesión BGP;
- el comando se ejecutó en una consola que no era la de DIST-1.

---

## 11. Archivos del checkpoint

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

**Siguiente paso:** R1 revisa este checkpoint. No se ejecuta ningún drill ni prueba de seguridad sin su autorización individual.
