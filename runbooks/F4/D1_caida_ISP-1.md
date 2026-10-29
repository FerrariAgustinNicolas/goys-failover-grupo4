# D1 — Caída de ISP-1 y continuidad por ISP-2

**Estado:** borrador para revisión de R1. No ejecutar sin autorización individual.
**Dueño de la tarea:** R5 (ejecución y medición) · revisa R1 (EDGE) y R2 (ISP).
**Entorno:** copia GNS3 `failover_F2` de R5 (VM `SeguridadUbuntu1`), CHR RouterOS 7.16 emulados con TCG.

## 1. Objetivo y elementos afectados

Medir cuánto tarda la red en volver a salir a "Internet" por ISP-2 cuando se pierde el enlace con ISP-1, que hoy es el proveedor del default activo.

- **Falla simulada:** enlace ISP-1 `ether1` ↔ EDGE `ether1` (`10.255.0.0/30`).
- **Afectados:** sesión eBGP `ebgp-isp1`, default `0.0.0.0/0` activo, loopback `10.255.255.1/32`, LSA externos que origina EDGE.
- **No afectados (deben mantenerse):** sesión con ISP-2, OSPF (7 adyacencias), VRRP, firewall, SSH-MGMT.

## 2. Condiciones previas

- R1 autorizó este drill por escrito.
- Snapshot `PRE_F4` creado y línea base de F4 aprobada (ver `F4_00_PLAN_Y_PREFLIGHT_R5.md`).
- Respaldos `pre-drill1` de EDGE e ISP-1 hechos (sección 10).
- Carga de la VM estable durante 5 min, sin swap en crecimiento (umbral en el plan, sección 4).
- Consolas abiertas y con sesión iniciada por R5: EDGE, ISP-1, ISP-2, CORE-1, PC-USER y SRV.
- Sin otros cambios en curso.

## 3. Estado esperado antes de la falla

| Punto | Esperado |
| --- | --- |
| EDGE `/routing bgp session print` | `ebgp-isp1-1` y `ebgp-isp2-1` `established` |
| EDGE `/ip route print where dst-address=0.0.0.0/0` | Default activo vía `10.255.0.1` (ISP-1), respaldo vía `10.255.0.5` |
| EDGE rutas BGP | `10.255.255.1/32` vía ISP-1, `10.255.255.2/32` vía ISP-2 |
| CORE/DIST `/routing ospf lsa print where type=external` | 3 LSA externos |
| ISP-2 rutas BGP | Exactamente `192.168.10.0/24` y `192.168.20.0/24` |
| Hosts | PC-USER y SRV → `10.255.255.1` y `10.255.255.2`: 5/5 |

## 4. Acción propuesta para simular la falla

**Opción recomendada (sin cambio de configuración):** suspender en GNS3 el enlace ISP-1 ↔ EDGE (clic derecho sobre el enlace → *Suspend*). No modifica ningún router y deja la configuración idéntica antes y después.

**Alternativa (la usada en F3):** en ISP-1, `/interface disable ether1`. Cambia la configuración de ISP-1 hasta la reversión.

En los dos casos el enlace virtual de EDGE sigue "arriba" en GNS3: EDGE detecta la falla por el hold-time de BGP (180 s por defecto; en F3 se observó `HoldTimer expired` unos 3 min después). No se cambian timers ni se agrega BFD.

## 5. Puntos de observación

- **PC-USER:** `ping 10.255.255.1 -t` y, en paralelo desde SRV, `ping 10.255.255.2 -t` (una sonda por segundo; la pérdida se cuenta por los `icmp_seq` faltantes).
- **EDGE:** `/log print follow where topics~"bgp"` y, cada ~15 s, `/routing bgp session print` y `/ip route print where dst-address=0.0.0.0/0`.
- **CORE-1:** `/ip route print where dst-address=0.0.0.0/0` (el default debe seguir presente: EDGE sigue originándolo mientras tenga el de ISP-2).
- **ISP-2:** `/ip route print where bgp` (debe seguir recibiendo las dos LAN).
- **VM:** `uptime` y `free -m` al inicio, durante y al final.

## 6. Medición de tiempos

Ver la estrategia común en el plan (sección 5). Para D1:

| Marca | Cómo se obtiene | Reloj |
| --- | --- | --- |
| T0, falla | Hora del *Suspend* (o `:log info "F4-D1 T0"` en ISP-1 justo antes del `disable`) | VM / ISP-1 |
| T1, detección | `HoldTimer expired` de `ebgp-isp1` en el log de EDGE | EDGE |
| T2, servicio restablecido | Primer eco nuevamente respondido en el `ping -t` de PC-USER hacia `10.255.255.2`/default | Secuencia del ping |
| T3, convergencia | El default activo en EDGE pasa a ISP-2 y CORE/DIST tienen 2 LSA externos | EDGE / CORE |

- **Interrupción de servicio** = sondas perdidas × 1 s (no depende de relojes).
- **Detección** = T1 − T0, corrigiendo el desfase entre relojes medido antes del drill.
- **Expectativa (no es un resultado):** detección cercana a 180 s; durante ese tiempo el tráfico hacia el default se pierde.

## 7. Conectividad que debe mantenerse

- PC-USER ↔ SRV sin pérdida.
- SSH-MGMT a EDGE desde MGMT-CLIENT.
- 7 adyacencias OSPF `Full`; VRRP sin cambios.
- `10.255.255.2` alcanzable desde las dos LAN después de T3.
- `10.255.255.1` **deja de ser alcanzable** mientras ISP-1 está caído: es lo esperado según el diseño.

## 8. Condiciones de éxito y de fracaso

**Éxito:** después de la detección, el default activo pasa a ISP-2, las LAN alcanzan `10.255.255.2`, ISP-2 sigue recibiendo solo las dos LAN, y al revertir todo vuelve a la línea base (default otra vez vía ISP-1, 3 LSA externos).

**Fracaso (abortar y revertir):**
- no hay salida por ISP-2 5 min después de T0;
- cae alguna adyacencia OSPF o cambia un rol VRRP;
- ISP-2 recibe prefijos fuera de las dos LAN;
- la carga de la VM supera el umbral de aborto o una consola deja de responder.

## 9. Reversión

1. *Resume* del enlace en GNS3 (o `/interface enable ether1` en ISP-1).
2. Esperar `established` de `ebgp-isp1` en EDGE (en F3 tardó ~1 min).
3. Verificar la línea base completa (sección 3) y registrar T4, la vuelta del default a ISP-1.
4. Si la configuración quedó distinta: comparar con `pre-drill1` y, solo con autorización de R1, recargar la configuración de ese router (plan, sección 7).

## 10. Respaldos

| Momento | Routers | Contenido |
| --- | --- | --- |
| `pre-drill1` | EDGE, ISP-1 | `/export file=<router>_<AAAA-MM-DD>_pre-drill1` y `/system backup save name=<router>_<AAAA-MM-DD>_pre-drill1 encryption=aes-sha256` (contraseña tipeada por R5) |
| `post-drill1` | EDGE, ISP-1 | Ídem con `post-drill1` |

Con la opción *Suspend*, la configuración no cambia: el post-drill sirve como prueba de que no hubo cambios.

## 11. Evidencias requeridas

- Línea base previa (sección 3), en texto saneado.
- Salida completa de los dos `ping -t`, con los `icmp_seq`.
- Log BGP de EDGE desde T0 hasta T4.
- Rutas en EDGE y en CORE-1 durante la falla y después de revertir.
- `uptime` y `free -m` de la VM.
- Desfase entre relojes medido antes del drill.
- Nombre, tamaño y SHA-512 de los respaldos pre y post (sin contenido).

Ninguna evidencia debe contener `tcp-md5-key`. No usar `/routing bgp connection print`, que muestra la clave en claro.

## 12. Post-mortem

Usar la plantilla común del plan (sección 6): resumen, línea de tiempo T0–T4, interrupción medida, detección, qué funcionó, qué no, causa raíz de cualquier desvío, acciones y responsables.
