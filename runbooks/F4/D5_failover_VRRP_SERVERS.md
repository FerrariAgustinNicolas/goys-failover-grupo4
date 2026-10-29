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

- Autorización individual de R1, con conocimiento de R4.
- D4 cerrado y revertido; sus respaldos, trasladados y verificados.
- **Consola de SRV resuelta**, y SRV capaz de originar los pings de la línea base (pendiente al 29/10).
- Respaldos `pre-drill5` de DIST-1 y DIST-2.
- Carga de la VM dentro del umbral.
- Consolas de DIST-1, DIST-2, CORE-2, SRV y PC-USER con sesión iniciada.

## 3. Estado esperado antes de la falla

- DIST-2: `vrrp-servers-20` MASTER y `vrrp-users-10` BACKUP.
- DIST-1: lo inverso.
- SRV 5/5 a `192.168.20.1`, a PC-USER y a las loopbacks ISP.

## 4. Acción propuesta

**Método aprobado por R1 (29/10):** deshabilitar solo `ether4` (SERVERS) de DIST-2, sin tocar las demás interfaces. Es el mismo método que en D4, así que los resultados son comparables.

**Verificación previa (en DIST-2):** `/system identity print`, `/interface vrrp print` (`vrrp-servers-20` en `ether4`, MASTER) y `:put [/interface get ether4 disabled]`, que debe dar `false`.

**Ejecución:** `:log info "F4-D5 T0"; /interface disable ether4`

**Reversión:** `:log info "F4-D5 T4"; /interface enable ether4`

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

1. Ejecutar la reversión (`enable ether4`).
2. Verificar DIST-2 MASTER y DIST-1 BACKUP en VRID 20, y VRID 10 sin cambios.
3. SRV 5/5.
4. Línea base completa de cierre de drills.

## 10. Respaldos

`pre-drill5` y `post-drill5` de DIST-1 y DIST-2, trasladados y verificados con SHA-512 antes de D3.

El juego final `post-f4` de los siete routers **no** corresponde a D5. Se genera al cierre de todos los drills y de las pruebas de seguridad (plan, sección 2.4).

## 11. Evidencias

Las mismas que en D4, para SERVERS.

## 12. Post-mortem

- Plantilla común del plan (sección 6).
- Comparación D4 contra D5.

El post-mortem global se hace después de D2, el último drill del orden aprobado.
