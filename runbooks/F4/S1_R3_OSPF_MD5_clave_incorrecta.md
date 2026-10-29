# S1 (R3) — Clave OSPF MD5 incorrecta en un extremo

**Estado:** borrador. No ejecutar sin autorización individual de R1 y conocimiento de R3.
**Reglas de claves:** la clave aprobada no se cambia de forma permanente y no se muestra a Claude, ni en capturas, logs públicos o GitHub. La restaura una persona (R5 o R3) tipeándola localmente, con el uso de computadora de Claude **pausado** mientras tanto.

## 1. Objetivo

Demostrar que una adyacencia OSPF no se forma, o se cae, cuando un extremo usa una clave MD5 distinta, y que se recupera al restaurarla.

## 2. Alcance propuesto (mínimo impacto)

- **Enlace:** CORE-2 `ether4` ↔ DIST-2 `ether2` (`10.255.0.32/30`).
- **Extremo modificado:** DIST-2, solo el `interface-template` de `ether2`. Cada interfaz tiene su propio template, así que no afecta `ether1` (hacia CORE-1).
- **Valor de prueba:** uno ficticio y no secreto, por ejemplo `F4-PRUEBA-INCORRECTA`. Si la política lo prefiere, otro que defina R3.

## 3. Condiciones previas

- Línea base: 7 adyacencias `Full`.
- Respaldo `pre-sec1` de DIST-2 (export y backup cifrado).
- Consolas de DIST-2, CORE-2 y CORE-1 abiertas; PC-USER y SRV con `ping -t` hacia SRV/PC-USER y hacia una loopback ISP.
- Carga de la VM dentro del umbral.

## 4. Acción (no ejecutar todavía)

```routeros
:log info "F4-S1 T0"
/routing ospf interface-template set [find interfaces=ether2] auth-key="F4-PRUEBA-INCORRECTA"
```

No usar `print` ni `export` sobre los templates durante la prueba: muestran `auth-key`.

## 5. Efecto previsto (a confirmar en la prueba)

- CORE-2 y DIST-2 dejan de aceptar los hellos del otro. La adyacencia cae al vencer el dead-interval (40 s) y no vuelve a `Full`.
- Quedan 6 adyacencias `Full`. DIST-2 sigue alcanzable por CORE-1; el tráfico se reacomoda sin pérdida duradera.
- En el log de CORE-2 o DIST-2 puede aparecer un error de autenticación OSPF; si aparece, es evidencia directa.

## 6. Riesgos

- Una pérdida breve en los flujos que usaban CORE-2 ↔ DIST-2, hasta la reconvergencia.
- Riesgo de tipear el valor en el template equivocado: hay que verificar con `/routing ospf interface-template print count-only where interfaces=ether2`, que devuelve un número y no la clave.
- La restauración exige tipear la clave aprobada. Un error de tipeo deja la adyacencia caída; se corrige reintentando.

## 7. Evidencia necesaria

- `/routing ospf neighbor print` en CORE-2 y DIST-2: antes, durante (después de 60 s) y después.
- Log OSPF de los dos, revisado antes de guardarlo.
- `ping -t` completos.
- Hora de T0 y de la restauración.

Ninguna salida debe incluir `auth-key`.

## 8. Restauración

1. Claude pausa el uso de computadora y lo informa.
2. R5 o R3, en la consola de DIST-2, ejecuta `/routing ospf interface-template set [find interfaces=ether2] auth-key="<clave aprobada>"`, tipeada localmente.
3. Limpia la pantalla de la consola antes de reanudar.
4. Verificar que la adyacencia CORE-2–DIST-2 vuelve a `Full` y que hay 7 `Full` en total.

Esto prueba que la clave restaurada coincide con la del otro extremo.

**Plan B:** si no vuelve a `Full`, se recarga el backup `pre-sec1` de DIST-2, solo con autorización de R1. No se publica el export de DIST-2 sin sanear.

## 9. Respaldos

`pre-sec1` y `post-sec1` de DIST-2.
