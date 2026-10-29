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
- D4 y D5 cerrados y revertidos, con la línea base verificada (orden aprobado: D4 → D5 → D3 → D1 → D2).
- Respaldos `pre-drill3` de CORE-1.
- Carga de la VM dentro del umbral.
- Consolas de EDGE, CORE-2, DIST-1, DIST-2, PC-USER y SRV con sesión iniciada.

## 3. Estado esperado antes de la falla

- 7 adyacencias `Full`.
- EDGE con ECMP vía `10.255.0.10` y `10.255.0.14` hacia las LAN.
- DIST-1 y DIST-2 con ECMP hacia el default y las loopbacks ISP vía los dos CORE.
- Hosts 5/5 hacia las dos loopbacks y entre sí.

## 4. Acción (método elegido por R1, 29/10)

Deshabilitar `ether1` a `ether4` de CORE-1 **en una única ejecución validada**, sin tocar `ether5` (la red MGMT). La ejecución necesita una autorización separada de R1, después de revisar los comandos de esta sección.

**4.1 Verificación previa (solo lectura, en la consola de CORE-1):**

```routeros
/system identity print
/interface print where (name=ether1 or name=ether2 or name=ether3 or name=ether4 or name=ether5)
/ip address print where interface=ether5
:put [/interface print count-only where (name=ether1 or name=ether2 or name=ether3 or name=ether4) and disabled=no]
```

Esperado:
- identidad `CORE-1`;
- `ether5` con `172.31.250.4/28`, en la VRF `MGMT`;
- `ether1` a `ether4` habilitadas: el `count-only` devuelve `4`.

Si algo difiere, no se ejecuta.

**4.2 Ejecución (una sola línea):**

```routeros
:log info "F4-D3 T0"; /interface disable ether1,ether2,ether3,ether4
```

**4.3 Verificación inmediata:**

```routeros
:put [/interface print count-only where (name=ether1 or name=ether2 or name=ether3 or name=ether4) and disabled=yes]
:put [/interface get ether5 disabled]
```

Esperado: `4` y `false`. Si no se cumple, se revierte de inmediato.

**4.4 Reversión:**

```routeros
:log info "F4-D3 T4"; /interface enable ether1,ether2,ether3,ether4
:put [/interface print count-only where (name=ether1 or name=ether2 or name=ether3 or name=ether4) and disabled=no]
```

Esperado: `4`.

Aunque las interfaces de CORE-1 se deshabilitan, GNS3 puede mantener activa la interfaz virtual del **lado vecino**. Por eso EDGE, CORE-2, DIST-1 y DIST-2 detectan la falla por el protocolo: el dead-interval de OSPF es de 40 s en enlaces `ptp` con valores por defecto.

## 5. Puntos de observación

- **PC-USER y SRV:** `ping 10.255.255.1 -t` y `ping 192.168.20.100 -t` / `ping 192.168.10.100 -t`, con el intervalo efectivo calibrado antes del drill (plan, sección 5).
- **EDGE, CORE-2, DIST-1 y DIST-2:** `/routing ospf neighbor print` y `/log print follow where topics~"ospf"`.
- **EDGE:** `/ip route print where dst-address~"192.168."` (ECMP → un solo nexthop, `10.255.0.14`).
- **DIST-1:** `/ip route print where dst-address=0.0.0.0/0` (ECMP → un solo nexthop por CORE-2).
- **VM:** `uptime` y `free -m`.

## 6. Medición de tiempos

| Marca | Fuente |
| --- | --- |
| T0 | Marcador `F4-D3 T0` en el log de CORE-1 |
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

1. Ejecutar la reversión de la sección 4.4 y comprobar el resultado `4`.
2. Esperar las 7 adyacencias `Full` y el ECMP restablecido en EDGE y en los DIST.
3. Comparar el export `post-drill3` de CORE-1 con `pre-drill3`: solo debe cambiar la línea del encabezado.

## 10. Respaldos

`pre-drill3` y `post-drill3` de CORE-1, trasladados y verificados con SHA-512 antes de D1. El resto de los routers no cambia la configuración; su estado se acredita con la línea base.

## 11. Evidencias

- Vecinos OSPF de los cuatro routers antes, durante y después.
- Rutas ECMP de EDGE y DIST-1.
- `ping -t` completos.
- Logs OSPF.
- Carga de la VM.
- Metadatos de los respaldos.

## 12. Post-mortem

Plantilla común del plan (sección 6), con atención a la diferencia entre flujos que pasaban por CORE-1 y por CORE-2.
