# S3 (R4) — Clave VRRP incorrecta en uno de los grupos

**Estado:** objetivo aprobado por R1 el 29/10; la ejecución sigue sin autorizar. Requiere autorización individual de R1 y conocimiento de R4.
**Reglas de claves:** la clave aprobada no se cambia de forma permanente ni se muestra a Claude, capturas, logs públicos o GitHub. La restaura R5 o R4 tipeándola localmente, con el uso de computadora de Claude pausado.

## 1. Objetivo

Observar qué pasa en un grupo VRRP cuando el backup usa una clave distinta de la del master, y comprobar que vuelve a la normalidad al restaurarla.

## 2. Alcance propuesto

- **Grupo:** USERS, VRID 10 (`vrrp-users-10`).
- **Extremo modificado:** DIST-2, el backup del grupo, con prioridad 100. El master DIST-1 no se toca.
- **Valor de prueba:** ficticio, no secreto y de 8 caracteres o menos, por ejemplo `F4WRONG1`.

## 3. Condiciones previas

- Línea base VRRP: DIST-1 master de VRID 10 y DIST-2 master de VRID 20.
- Respaldo `pre-sec3` de DIST-2.
- Consolas de DIST-1 y DIST-2; PC-USER con `ping 192.168.10.1 -t` y `ping 192.168.20.100 -t`.

## 4. Acción (no ejecutar todavía)

```routeros
:log info "F4-S3 T0"
/interface vrrp set [find name=vrrp-users-10] password="F4WRONG1"
```

## 5. Efecto previsto (a confirmar en la prueba)

Con autenticación `simple` (VRRPv2), DIST-2 debería descartar los anuncios de DIST-1 por no coincidir la clave. Al vencer el intervalo de caída (~3,6 s), DIST-2 se declararía MASTER:
- **doble master** en VRID 10, con los dos routers respondiendo por la misma IP y la misma MAC virtual;
- en SW-USERS, la MAC virtual puede aparecer alternadamente en dos puertos, y PC-USER puede ver pérdidas intermitentes o ninguna;
- VRID 20 (SERVERS) no debería cambiar.

Si el doble master no ocurre, también es un resultado válido y se registra tal cual.

## 6. Riesgos

- **El doble master es un riesgo relevante** (decisión de R1, 29/10). No se mantiene intencionalmente: apenas se captura el estado de los dos DIST, se restaura la clave de inmediato.
- Modificar el grupo o el router equivocado: verificar `name=vrrp-users-10` en DIST-2.
- La restauración exige tipear la clave aprobada. Si se tipea mal, el doble master sigue; se reintenta.

## 7. Evidencia necesaria

- `/interface vrrp print` en los dos DIST: antes, durante y después. No muestra la contraseña; igual se revisa.
- Logs VRRP de los dos DIST.
- `ping -t` completos.
- T0 y hora de la restauración.

## 8. Restauración

1. Claude pausa el uso de computadora y lo informa.
2. R5 o R4, en DIST-2, ejecuta `/interface vrrp set [find name=vrrp-users-10] password="<clave aprobada>"`, tipeada localmente.
3. Limpia la pantalla de la consola antes de reanudar.
4. Verificar que DIST-2 vuelve a BACKUP en VRID 10, que DIST-1 sigue MASTER y que VRID 20 no cambió.

Que DIST-2 vuelva a BACKUP prueba que las claves coinciden.

**Plan B:** recargar el backup `pre-sec3` de DIST-2, solo con autorización de R1.

## 9. Respaldos

`pre-sec3` y `post-sec3` de DIST-2.
