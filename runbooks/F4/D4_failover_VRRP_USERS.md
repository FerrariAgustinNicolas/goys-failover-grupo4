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

D4 es el **primer drill**. Antes de ejecutarlo tiene que cumplirse todo esto:
- Autorización individual de R1, con conocimiento de R4.
- Transferencia de los 16 respaldos privados de F3 a R1 completada, con 16/16 SHA-512 confirmados por R1.
- Si se hace la prueba de restore aislado de ISP-1 (plan, sección 7), terminada antes de D4.
- Juego inicial `pre-f4` de los siete routers generado, trasladado fuera de los routers y verificado con SHA-512.
- Respaldos `pre-drill4` de DIST-1 y DIST-2.
- Recursos dentro de los márgenes del plan (sección 4); sin congelamientos recientes de la VM.
- Carga de la VM dentro del umbral.
- Consolas de DIST-1, DIST-2, CORE-1, PC-USER y SRV con sesión iniciada.

## 3. Estado esperado antes de la falla

- DIST-1: `vrrp-users-10` MASTER y `vrrp-servers-20` BACKUP.
- DIST-2: lo inverso.
- PC-USER 5/5 a `192.168.10.1`, a SRV y a las loopbacks ISP.

## 4. Acción (método aprobado por R1, 29/10)

Deshabilitar solo `ether3` (USERS) de DIST-1, sin tocar las demás interfaces. Es una falla abrupta del enlace LAN: DIST-1 deja de anunciar VRRP y además retira de OSPF su ruta conectada a USERS, como pasaría con un enlace real caído.

**4.1 Verificación previa (solo lectura, en DIST-1):**

```routeros
/system identity print
/interface vrrp print
:put [/interface get ether3 disabled]
```

Esperado:
- identidad `DIST-1`;
- `vrrp-users-10` en `ether3` y MASTER;
- `ether3` habilitada (`false`).

**4.2 Ejecución (una línea):**

```routeros
:log info "F4-D4 T0"; /interface disable ether3
```

**4.3 Reversión:**

```routeros
:log info "F4-D4 T4"; /interface enable ether3
```

> Se descartaron, por decisión de R1, el *Suspend* del enlace en GNS3 (DIST-1 seguiría anunciando USERS y se perdería tráfico de retorno) y `/interface vrrp disable`, que es una salida ordenada y no una falla.

## 5. Puntos de observación

- **PC-USER:** `ping 192.168.10.1 -t` y, en una segunda corrida, `ping 192.168.20.100 -t` (tráfico que atraviesa el gateway).
- **DIST-2:** `/interface vrrp print` y `/log print follow where topics~"vrrp"` (transición BACKUP → MASTER).
- **DIST-1:** log VRRP y estado, consultados por consola.
- **CORE-1:** rutas hacia `192.168.10.0/24`. Después de la convergencia OSPF, el nexthop DIST-1 debe desaparecer y quedar solo DIST-2.

## 6. Medición de tiempos

| Marca | Fuente |
| --- | --- |
| T0 | `F4-D4 T0` en el log de DIST-1 (mismo comando que el `disable`) |
| T1 | DIST-2 pasa a MASTER (log de DIST-2; su reloj se corrige con el desfase medido antes del drill) |
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

1. Ejecutar la reversión de la sección 4.3.
2. Verificar DIST-1 MASTER y DIST-2 BACKUP en VRID 10, y VRID 20 sin cambios.
3. PC-USER 5/5.

## 10. Respaldos

`pre-drill4` y `post-drill4` de DIST-1 y DIST-2, trasladados fuera de los routers y verificados con SHA-512 antes de D5.

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
