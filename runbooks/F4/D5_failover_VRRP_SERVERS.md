# D5 — Failover VRRP de SERVERS (DIST-2 → DIST-1)

**Estado:** borrador para revisión de R1. No ejecutar sin autorización individual.
**Dueño de la tarea:** R5 (ejecución y medición) · revisa R4 (DIST).
**Entorno:** copia GNS3 `failover_F2` de R5, CHR RouterOS 7.16 con TCG.

## 1. Objetivo y elementos afectados

Es el espejo de D4 para el gateway `192.168.20.1` (VRID 20).

- **Falla simulada:** enlace DIST-2 `ether4` ↔ SW-SERVERS.
- **Afectados:** `vrrp-servers-20` (DIST-2 master, prioridad 150; DIST-1 backup, prioridad 100).
- **No afectados:** VRID 10 (USERS), OSPF, BGP, firewall.

## 2. Condiciones previas

- Autorización de R1, con conocimiento de R4.
- D4 cerrado y revertido.
- Respaldos `pre-drill5` de DIST-1 y DIST-2.
- Carga de la VM dentro del umbral.
- Consolas de DIST-1, DIST-2, CORE-2, SRV y PC-USER con sesión iniciada.

## 3. Estado esperado antes de la falla

- DIST-2: `vrrp-servers-20` MASTER y `vrrp-users-10` BACKUP.
- DIST-1: lo inverso.
- SRV 5/5 a `192.168.20.1`, a PC-USER y a las loopbacks ISP.

## 4. Acción propuesta

Las mismas tres opciones que en D4, aplicadas a DIST-2 y SERVERS:
- **B (recomendada):** en DIST-2, `/interface disable ether4`. Además del VRRP, retira de OSPF la ruta conectada de SERVERS.
- **A:** *Suspend* del enlace DIST-2 ↔ SW-SERVERS. No cambia la configuración, pero DIST-2 sigue anunciando SERVERS y el retorno por ECMP podría perderse.
- **C:** en DIST-2, `/interface vrrp disable vrrp-servers-20`. Es una salida ordenada, no una falla.

Conviene usar la misma opción que en D4 para que los resultados sean comparables.

## 5. Puntos de observación

- **SRV:** `ping 192.168.20.1 -t` y, en otra corrida, `ping 192.168.10.100 -t`.
- **DIST-1:** transición BACKUP → MASTER en VRID 20 (log y `print`).
- **DIST-2:** estado y log.
- **CORE-2:** rutas hacia `192.168.20.0/24`, con la misma observación sobre el retorno por ECMP que en D4.

## 6. Medición de tiempos

Las mismas marcas que en D4 (T0, T1, T2, T4 y T5), con DIST-1 como nuevo master.

**Expectativa (no es un resultado):** unos 3,6 s más la demora de TCG.

## 7. Conectividad que debe mantenerse

USERS sin cambios: PC-USER → `192.168.10.1` sin pérdida. OSPF y BGP intactos.

## 8. Éxito y fracaso

Los mismos criterios que en D4, aplicados a VRID 20.

## 9. Reversión

1. *Resume* del enlace (o la reversión de la opción usada).
2. Verificar DIST-2 MASTER y DIST-1 BACKUP en VRID 20, y VRID 10 sin cambios.
3. SRV 5/5.
4. Línea base completa de cierre de drills.

## 10. Respaldos

`pre-drill5` y `post-drill5` de DIST-1 y DIST-2. El `post-drill5` de los siete routers sirve además como **juego de cierre de F4** (plan, sección 7).

## 11. Evidencias

Las mismas que en D4, para SERVERS.

## 12. Post-mortem

- Plantilla común del plan (sección 6).
- Comparación D4 contra D5.
- Post-mortem global de los cinco drills.
