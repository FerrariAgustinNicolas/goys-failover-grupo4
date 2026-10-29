# D4 — Failover VRRP de USERS (DIST-1 → DIST-2)

**Estado:** borrador para revisión de R1. No ejecutar sin autorización individual.
**Dueño de la tarea:** R5 (ejecución y medición) · revisa R4 (DIST).
**Entorno:** copia GNS3 `failover_F2` de R5, CHR RouterOS 7.16 con TCG.

## 1. Objetivo y elementos afectados

Medir el tiempo de conmutación del gateway `192.168.10.1` (VRID 10) cuando DIST-1, el master, deja de anunciar en USERS, y medir también la vuelta (preempt) al restablecerse.

- **Falla simulada:** enlace DIST-1 `ether3` ↔ SW-USERS.
- **Afectados:** `vrrp-users-10` (DIST-1 master, prioridad 150; DIST-2 backup, prioridad 100), la ruta conectada de USERS en DIST-1.
- **No afectados:** VRID 20 (SERVERS), OSPF, BGP, firewall.

Parámetros de diseño (memoria 1.2): VRRPv2, anuncios de 1 s, preempt habilitado. El intervalo teórico de caída para el backup es 3,609375 s. Es un valor teórico, no una medición.

## 2. Condiciones previas

- Autorización de R1, con conocimiento de R4.
- Drills anteriores cerrados.
- Respaldos `pre-drill4` de DIST-1 y DIST-2.
- Carga de la VM dentro del umbral.
- Consolas de DIST-1, DIST-2, CORE-1, PC-USER y SRV con sesión iniciada.

## 3. Estado esperado antes de la falla

- DIST-1: `vrrp-users-10` MASTER y `vrrp-servers-20` BACKUP.
- DIST-2: lo inverso.
- PC-USER 5/5 a `192.168.10.1`, a SRV y a las loopbacks ISP.

## 4. Acción propuesta (decisión de R1)

| Opción | Acción | Qué mide |
| --- | --- | --- |
| **B (recomendada)** | En DIST-1, `/interface disable ether3` | Falla abrupta del enlace LAN: DIST-1 deja de anunciar y además retira de OSPF su ruta conectada a USERS, como pasaría con un enlace real caído. Cambia la configuración hasta la reversión (`enable`) |
| A | *Suspend* en GNS3 del enlace DIST-1 ↔ SW-USERS | No cambia la configuración, pero GNS3 no baja la portadora: DIST-1 sigue anunciando `192.168.10.0/24` por OSPF y el tráfico de retorno que el ECMP de los CORE le mande se perdería. Mide un escenario distinto (falla "silenciosa" del switch) |
| C | En DIST-1, `/interface vrrp disable vrrp-users-10` (lo usado en F2) | Salida "ordenada": puede anunciar prioridad 0 y producir un failover casi inmediato. No representa una falla |

Con la opción A, DIST-1 queda aislado de USERS y se sigue viendo MASTER a sí mismo; hacia los hosts no hay doble master, porque ya no los alcanza. Si R1 prefiere A para no tocar la configuración, la pérdida de retorno pasa a ser un resultado esperado y hay que registrarla.

## 5. Puntos de observación

- **PC-USER:** `ping 192.168.10.1 -t` y, en una segunda corrida, `ping 192.168.20.100 -t` (tráfico que atraviesa el gateway).
- **DIST-2:** `/interface vrrp print` y `/log print follow where topics~"vrrp"` (transición BACKUP → MASTER).
- **DIST-1:** log VRRP y estado, consultados por consola.
- **CORE-1:** rutas hacia `192.168.10.0/24`. Con la opción B, el nexthop DIST-1 debe desaparecer (después de la convergencia OSPF) y quedar solo DIST-2. Con la opción A no desaparece; ver la sección 4.

## 6. Medición de tiempos

| Marca | Fuente |
| --- | --- |
| T0 | `:log info "F4-D4 T0"` en DIST-1 inmediatamente antes del `disable` (mismo comando encadenado), o hora del *Suspend* |
| T1 | DIST-2 pasa a MASTER (log de DIST-2) |
| T2 | Fin de la racha de pérdidas en PC-USER |
| T4 / T5 | Failback: *Resume* → DIST-1 vuelve a MASTER por preempt; pérdidas durante la vuelta |

**Expectativa (no es un resultado):** unos 3,6 s más la demora de TCG para el failover, y una interrupción breve en el failback.

## 7. Conectividad que debe mantenerse

SERVERS sin cambios: SRV → `192.168.20.1` sin pérdida. OSPF y BGP intactos. Después de T2, PC-USER alcanza SRV y las loopbacks ISP.

## 8. Éxito y fracaso

**Éxito:**
- DIST-2 es MASTER de VRID 10 dentro de un margen razonable del valor teórico;
- PC-USER recupera conectividad;
- al revertir, DIST-1 vuelve a MASTER y los roles quedan como en la línea base.

**Fracaso:**
- no hay conmutación;
- hay doble master visible desde la LAN (después del *Resume*);
- SERVERS se ve afectado;
- la pérdida de retorno persiste después de la conmutación;
- la carga de la VM supera el umbral de aborto.

## 9. Reversión

1. *Resume* del enlace (o `/interface enable ether3`, o `/interface vrrp enable vrrp-users-10`).
2. Verificar DIST-1 MASTER y DIST-2 BACKUP en VRID 10, y VRID 20 sin cambios.
3. PC-USER 5/5.

## 10. Respaldos

`pre-drill4` y `post-drill4` de DIST-1 y DIST-2.

## 11. Evidencias

- `/interface vrrp print` de los dos DIST antes, durante y después.
- Logs VRRP.
- `ping -t` completos.
- Rutas a USERS en CORE-1.
- Carga de la VM.
- Metadatos de los respaldos.

La contraseña VRRP no aparece en `print` ni en `export`; igual se revisa cada salida antes de guardarla.

## 12. Post-mortem

Plantilla común del plan (sección 6), separando failover y failback.
