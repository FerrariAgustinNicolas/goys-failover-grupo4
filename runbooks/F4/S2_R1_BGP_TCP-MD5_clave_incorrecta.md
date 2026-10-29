# S2 (R1) — Clave TCP-MD5 incorrecta en una sesión BGP de EDGE

**Estado:** objetivo aprobado por R1 el 29/10; la ejecución sigue sin autorizar. **Reservada a una autorización explícita de R1 sobre EDGE.**
**Reglas de claves:** la clave aprobada no se cambia de forma permanente ni se muestra a Claude, capturas, logs públicos o GitHub. La restaura R5 o R1 tipeándola localmente, con el uso de computadora de Claude pausado.

## 1. Objetivo

Demostrar que la sesión eBGP no se establece cuando EDGE usa una clave TCP-MD5 distinta de la del ISP, y que vuelve a `established` al restaurarla.

## 2. Alcance propuesto (mínimo impacto)

- **Sesión:** `ebgp-isp2` (EDGE ↔ ISP-2), la del proveedor de respaldo. Así el default activo vía ISP-1 no se ve afectado.
- **Extremo modificado:** EDGE.
- **Valor de prueba:** ficticio y no secreto, por ejemplo `F4-PRUEBA-INCORRECTA`.

## 3. Condiciones previas

- Línea base: 2 sesiones `established`, default vía ISP-1.
- Respaldo `pre-sec2` de EDGE.
- Consolas de EDGE, ISP-2 y CORE-1; SRV con `ping 10.255.255.2 -t` y PC-USER con `ping 10.255.255.1 -t`.

## 4. Acción (no ejecutar todavía)

```routeros
:log info "F4-S2 T0"
/routing bgp connection set [find name=ebgp-isp2] tcp-md5-key="F4-PRUEBA-INCORRECTA"
```

- **No usar `/routing bgp connection print`:** en 7.16 muestra `tcp-md5-key` en claro, incluso en formato simple. Las sesiones se consultan solo con `/routing bgp session print`.
- `export` no incluye la clave, así que tampoco sirve para comprobar la restauración. La prueba de que se restauró bien es que la sesión vuelva a `established`.

## 5. Efecto previsto (a confirmar en la prueba)

- Al cambiar el parámetro, RouterOS reinicia la conexión. El ISP descarta los segmentos TCP con una firma MD5 que no coincide, así que la sesión no vuelve a `established`.
- Se retiran `10.255.255.2/32` y el default de respaldo. El default activo sigue vía ISP-1 y PC-USER no pierde sondas hacia `10.255.255.1`.
- Los logs pueden mostrar intentos de conexión sin éxito. Si ISP-2 registra el descarte por MD5, es evidencia directa.

## 6. Riesgos

- Tocar la sesión equivocada (`ebgp-isp1`) dejaría sin default activo durante la prueba. Hay que verificar el nombre antes de ejecutar.
- La restauración exige tipear la clave aprobada. Si se tipea mal, la sesión sigue caída; se reintenta.
- Exposición accidental de la clave al consultar la conexión: ver la regla de la sección 4.

## 7. Evidencia necesaria

- `/routing bgp session print` en EDGE e ISP-2: antes, durante (después de 60 s) y después.
- Rutas BGP de EDGE.
- `ping -t` completos.
- Logs BGP revisados.
- T0 y hora de la restauración.

## 8. Restauración

1. Claude pausa el uso de computadora y lo informa.
2. R5 o R1, en EDGE, ejecuta `/routing bgp connection set [find name=ebgp-isp2] tcp-md5-key="<clave aprobada>"`, tipeada localmente.
3. Limpia la pantalla de la consola antes de reanudar.
4. Verificar `ebgp-isp2-1` `established`, `10.255.255.2/32` de vuelta y 3 LSA externos.

**Plan B:** recargar el backup `pre-sec2` de EDGE, solo con autorización de R1.

## 9. Respaldos

`pre-sec2` y `post-sec2` de EDGE.
