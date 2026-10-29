# D3 — Caída de CORE-1 y continuidad por CORE-2

**Estado:** borrador para revisión de R1. No ejecutar sin autorización individual.
**Dueño de la tarea:** R5 (ejecución y medición) · revisa R3 (CORE).
**Entorno:** copia GNS3 `failover_F2` de R5, CHR RouterOS 7.16 con TCG.

## 1. Objetivo y elementos afectados

Medir cuánto tarda OSPF en sacar a CORE-1 del camino y cuánto se interrumpe el tráfico, que hoy se reparte por ECMP entre CORE-1 y CORE-2.

- **Falla simulada:** CORE-1 completo. Sus cuatro enlaces de producción son `ether1` hacia EDGE, `ether2` hacia CORE-2, `ether3` hacia DIST-1 y `ether4` hacia DIST-2.
- **Afectados:** 4 de las 7 adyacencias OSPF (EDGE–CORE-1, CORE-1–CORE-2, CORE-1–DIST-1 y CORE-1–DIST-2) y los caminos ECMP vía CORE-1.
- **No afectados:** BGP, VRRP, firewall y la gestión del resto de los routers.

## 2. Condiciones previas

- Autorización de R1, con conocimiento de R3.
- D1 y D2 cerrados, con la línea base verificada.
- Respaldos `pre-drill3` de CORE-1.
- Carga de la VM dentro del umbral, con margen: la opción de detener el nodo genera un pico de CPU al rearrancarlo.
- Consolas de EDGE, CORE-2, DIST-1, DIST-2, PC-USER y SRV con sesión iniciada.

## 3. Estado esperado antes de la falla

- 7 adyacencias `Full`.
- EDGE con ECMP vía `10.255.0.10` y `10.255.0.14` hacia las LAN.
- DIST-1 y DIST-2 con ECMP hacia el default y las loopbacks ISP vía los dos CORE.
- Hosts 5/5 hacia las dos loopbacks y entre sí.

## 4. Acción propuesta (decisión de R1)

| Opción | Acción | Ventaja | Riesgo |
| --- | --- | --- | --- |
| **A (recomendada)** | Suspender en GNS3, en un mismo paso, los cuatro enlaces de producción de CORE-1, sin tocar el de MGMT | No cambia la configuración; CORE-1 sigue encendido y consultable por MGMT | Cuatro *Suspend* manuales tienen segundos de diferencia; se pueden lanzar juntos con la API de GNS3 desde la terminal de la VM, si R1 lo autoriza |
| B | Detener el nodo CORE-1 en GNS3 | Una sola acción, falla realista de equipo | Rearranque lento con TCG, pico de carga y posibles mensajes de arranque crítico como los del 17/10 y el 25/10 |
| C | En CORE-1, `/interface disable ether1,ether2,ether3,ether4` | Un solo comando, instante preciso | Cambia la configuración hasta la reversión |

Con cualquier opción, los vecinos detectan la falla por el dead-interval de OSPF (40 s en enlaces `ptp` con valores por defecto), porque GNS3 no baja la portadora del lado vecino.

## 5. Puntos de observación

- **PC-USER y SRV:** `ping 10.255.255.1 -t` y `ping 192.168.20.100 -t` / `ping 192.168.10.100 -t`, una sonda por segundo.
- **EDGE, CORE-2, DIST-1 y DIST-2:** `/routing ospf neighbor print` y `/log print follow where topics~"ospf"`.
- **EDGE:** `/ip route print where dst-address~"192.168."` (ECMP → un solo nexthop, `10.255.0.14`).
- **DIST-1:** `/ip route print where dst-address=0.0.0.0/0` (ECMP → un solo nexthop por CORE-2).
- **VM:** `uptime` y `free -m`.

## 6. Medición de tiempos

| Marca | Fuente |
| --- | --- |
| T0 | *Suspend* / *Stop* (hora de la VM) o marcador de log en CORE-1 (opción C) |
| T1 | Primer `neighbor down` en EDGE, CORE-2, DIST-1 y DIST-2 (uno por router, con su reloj) |
| T2 | Fin de la racha de pérdidas en cada `ping -t` |
| T3 | Las rutas de EDGE y de los DIST sin nexthop por CORE-1 |

**Expectativa (no es un resultado):** pérdida parcial de los flujos que el hash ECMP manda por CORE-1, hasta ~40 s, y ninguna pérdida en los que van por CORE-2. Como el ECMP reparte por flujo, conviene medir varios destinos.

## 7. Conectividad que debe mantenerse

Después de T3: hosts → las dos loopbacks ISP, PC-USER ↔ SRV, BGP intacto (EDGE no depende de CORE-1 para hablar con los ISP), VRRP sin cambios y SSH-MGMT a los otros routers.

## 8. Éxito y fracaso

**Éxito:**
- después de T3, todo el tráfico va por CORE-2 sin pérdidas;
- 3 adyacencias `Full` (EDGE–CORE-2, CORE-2–DIST-1 y CORE-2–DIST-2);
- al revertir, vuelven las 7 adyacencias y el ECMP.

**Fracaso:**
- pérdida que continúa después de 90 s;
- cambio de un rol VRRP;
- cae una sesión BGP;
- CORE-1 no vuelve a la línea base;
- la carga de la VM supera el umbral de aborto.

## 9. Reversión

1. *Resume* de los cuatro enlaces (A), *Start* del nodo (B) o `/interface enable ether1,ether2,ether3,ether4` (C).
2. Esperar las 7 adyacencias `Full` y el ECMP restablecido en EDGE y en los DIST.
3. Con la opción B: revisar el `/log` de CORE-1 por mensajes de arranque y confirmar que la configuración es igual a `pre-drill3`.

## 10. Respaldos

`pre-drill3` y `post-drill3` de CORE-1. El resto de los routers no cambia la configuración; su estado se acredita con la línea base.

## 11. Evidencias

- Vecinos OSPF de los cuatro routers antes, durante y después.
- Rutas ECMP de EDGE y DIST-1.
- `ping -t` completos.
- Logs OSPF.
- Carga de la VM.
- Metadatos de los respaldos.

## 12. Post-mortem

Plantilla común del plan (sección 6), con atención a la diferencia entre flujos que pasaban por CORE-1 y por CORE-2.
