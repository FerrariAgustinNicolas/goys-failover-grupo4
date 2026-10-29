# D2 — Caída de ISP-2 y continuidad por ISP-1

**Estado:** borrador para revisión de R1. No ejecutar sin autorización individual.
**Dueño de la tarea:** R5 (ejecución y medición) · revisa R1 (EDGE) y R2 (ISP).
**Entorno:** copia GNS3 `failover_F2` de R5, CHR RouterOS 7.16 con TCG.

## 1. Objetivo y elementos afectados

Comprobar y medir que la caída del proveedor de respaldo no interrumpe la salida por ISP-1, y cuánto tarda la red en retirar las rutas de ISP-2.

- **Falla simulada:** enlace ISP-2 `ether1` ↔ EDGE `ether2` (`10.255.0.4/30`).
- **Afectados:** sesión `ebgp-isp2`, default de respaldo, `10.255.255.2/32` y su LSA externo.
- **No afectados:** default activo vía ISP-1, OSPF, VRRP, firewall, SSH-MGMT.

**Diferencia con D1:** como el default ya sale por ISP-1, se espera **cero pérdida** hacia `10.255.255.1`. Lo medible es el tiempo hasta que la red interna deja de anunciar `10.255.255.2/32`.

## 2. Condiciones previas

- Autorización de R1 para D2.
- D1 cerrado y revertido, con la línea base verificada.
- Respaldos `pre-drill2` de EDGE e ISP-2.
- Carga de la VM dentro del umbral.
- Consolas de EDGE, ISP-1, ISP-2, CORE-1, PC-USER y SRV con sesión iniciada.

## 3. Estado esperado antes de la falla

La misma línea base de D1, sección 3: dos sesiones `established`, default vía ISP-1, 3 LSA externos e ISP-1 recibiendo solo las dos LAN.

## 4. Acción propuesta

**Recomendada:** *Suspend* del enlace ISP-2 ↔ EDGE en GNS3.
**Alternativa (F3):** en ISP-2, `/interface disable ether1`.

La detección depende del hold-time de BGP (180 s); en F3 fue `HoldTimer expired` unos 3 min después del `disable`.

## 5. Puntos de observación

- **PC-USER:** `ping 10.255.255.1 -t`: no debe perder sondas.
- **SRV:** `ping 10.255.255.2 -t`: deja de responder; desde T3, ISP-1 devuelve `Destination network unreachable` (comportamiento de diseño visto en F3).
- **EDGE:** log BGP, sesiones y default activo.
- **CORE-1 y DIST-1:** `/routing ospf lsa print where type=external`, que debe pasar de 3 a 2.
- **ISP-1:** rutas BGP recibidas (solo las dos LAN).

## 6. Medición de tiempos

| Marca | Fuente |
| --- | --- |
| T0 | *Suspend* o marcador de log en ISP-2 |
| T1 | `HoldTimer expired` de `ebgp-isp2` en EDGE |
| T3 | Desaparece `10.255.255.2/32` en CORE-1/DIST-1 (2 LSA externos) |
| Pérdida hacia `10.255.255.1` | Sondas faltantes en el `ping -t` de PC-USER (esperado: 0) |

**Expectativa (no es un resultado):** T1 − T0 ≈ 180 s y ninguna pérdida hacia ISP-1.

## 7. Conectividad que debe mantenerse

`10.255.255.1` desde las dos LAN; PC-USER ↔ SRV; SSH-MGMT; 7 adyacencias `Full`; roles VRRP.

## 8. Éxito y fracaso

**Éxito:**
- 0 pérdidas hacia `10.255.255.1`;
- retiro limpio de `10.255.255.2/32`;
- al revertir, 2 sesiones, 3 LSA externos y el default de nuevo vía ISP-1.

**Fracaso:**
- pérdidas hacia ISP-1 sin explicación;
- el default se mueve;
- cae OSPF o VRRP;
- la carga de la VM supera el umbral de aborto.

## 9. Reversión

1. *Resume* del enlace (o `/interface enable ether1` en ISP-2).
2. Esperar `established` de `ebgp-isp2`.
3. Verificar la línea base completa.

Si la configuración cambió, seguir la sección 7 del plan.

## 10. Respaldos

`pre-drill2` y `post-drill2` de EDGE e ISP-2, con el mismo formato que D1.

## 11. Evidencias

- Línea base previa.
- Los dos `ping -t` completos.
- Log BGP de EDGE.
- LSA externos en CORE-1 antes, durante y después.
- Carga de la VM.
- Desfase entre relojes.
- Metadatos de los respaldos.

Sin `tcp-md5-key` en ninguna salida.

## 12. Post-mortem

Plantilla común del plan (sección 6).
