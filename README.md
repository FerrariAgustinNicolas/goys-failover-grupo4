# Laboratorio Failover Routing — la red que no se cae

**Materia:** Gestión Operativa y Seguridad en Redes  
**Universidad:** UTN FR La Plata  
**Grupo:** 4

## Objetivo

Diseñar, implementar, operar y asegurar una red empresarial jerárquica
de cinco capas con redundancia mediante VRRP, OSPF y BGP multi-homing,
capaz de mantener conectividad frente a fallas de enlaces y dispositivos.

## Integrantes y roles

| Integrante | Rol |
|---|---|
| Ferrari Agustin Nicolas | R1 — Líder / Edge-WAN |
| Siadore Valentino | R2 — Proveedores |
| Kloster Agustin Ignacio | R3 — Core |
| Guarino Naim | R4 — Distribución |
| Bellomo Lorenzo | R5 — Hosts / QA / Operación |

## Estado de las fases

| Fase | Descripción | Vencimiento | Estado |
|---|---|---|---|
| F0 | Diseño y gestión de cambio | 02/10/2026 | Aprobado por la cátedra: **100/100**. |
| F1 | Topología, hardening y backup | 09/10/2026 | Aprobado por la cátedra: **100/100**, sin correcciones bloqueantes. |
| F2 | VRRP y OSPF | 16/10/2026 | Ejecutada el 16 y 17/10; evidencias y exports en el repositorio. Pendiente de la devolución de la cátedra. |
| F3 | BGP y firewall | 16/10/2026 | Pendiente de ejecución. |
| F4 | Drills y monitoreo | 20/10/2026 | Pendiente de ejecución. |
| F5 | Memoria y defensa | 23/10/2026 | Pendiente de finalización. |

## Estado posterior a SSH-MGMT, previo a la implementación de F2 (14–16/10/2026)

En ese momento, la topología de GNS3 tenía 13 nodos y 23 enlaces: siete routers MikroTik CHR (RouterOS 7.16), ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1 y DIST-2; tres switches, SW-USERS, SW-SERVERS y SW-MGMT; y tres hosts, PC-USER, SRV y MGMT-CLIENT. La topología de F1 tenía 11 nodos y 15 enlaces; SW-MGMT, MGMT-CLIENT y los ocho enlaces de gestión se agregaron con SSH-MGMT. Los routers tenían aplicados el direccionamiento del IPAM, las loopbacks, el hardening de F1 y la gestión SSH-MGMT. VRRP, OSPF, BGP y el firewall de EDGE todavía no estaban configurados: VRRP y OSPF correspondían a la etapa siguiente, F2.

- **Cierre de F1 (09/10):** SSH quedó deshabilitado en los siete routers y la administración se hacía solo por la consola de GNS3. Exports en [`backups/2026-10-09/`](backups/2026-10-09/).
- **Red de gestión SSH-MGMT (14/10, posterior a F1):** cada router tiene una interfaz en la red aislada `172.31.250.0/28`, dentro de una VRF `MGMT`. SSH solo acepta conexiones desde `172.31.250.10/32`; R1 comprobó el acceso autorizado y el rechazo desde otra dirección en los siete routers. Exports en [`backups/2026-10-14/`](backups/2026-10-14/) (PR #18 a #21).
- **Backups binarios:** hay dos juegos cifrados de los siete routers, uno de F1 (10 y 13/10) y otro posterior a SSH-MGMT (15/10). Se guardan fuera del repositorio. En cada juego se restauró ISP-1 en un proyecto aislado; el restore del 16/10 requirió corregir a mano las referencias de interfaces. Los otros seis binarios de cada juego no se restauraron.

A esa fecha quedaban pendientes F2 a F5, sus backups por hito y el procedimiento privado de recuperación de credenciales. El detalle está en la memoria y en el backlog.

## Estado al cierre de F2 (16 y 17/10/2026)

R1 configuró y probó F2 en el proyecto GNS3 `topologia_failover_F1_SSH_MGMT`, sin cambiar la topología. R2, R3 y R4 revisaron y publicaron los exports de sus routers.

- **VRRP:** dos grupos con load-sharing. USERS (VRID 10, `192.168.10.1`) tiene a DIST-1 como master preferido, y SERVERS (VRID 20, `192.168.20.1`) a DIST-2. Los dos grupos usan autenticación `simple`. Se comprobaron los estados MASTER/BACKUP y un failover reversible; no se midieron tiempos.
- **OSPF:** OSPFv2 en el área 0 con MD5 en EDGE, CORE-1, CORE-2, DIST-1 y DIST-2. Las siete adyacencias, incluida la core–core, están en `Full`. EDGE aprende las LAN y las loopbacks de DIST por ECMP. Los ISP no tienen OSPF ni BGP.
- **Conectividad:** los dos hosts alcanzan su gateway virtual. PC-USER (`192.168.10.100`) y SRV (`192.168.20.100`) se alcanzan en ambos sentidos, y las dos LAN alcanzan la loopback de EDGE (`10.255.255.3`); todo con 5/5. Después de una parada y un arranque del proyecto, PC-USER volvió a alcanzar a SRV.
- **Respaldos:** los siete exports saneados están en [`backups/2026-10-16/`](backups/2026-10-16/) (PR #23 a #26). R1 guardó fuera del repositorio siete exports originales y siete backups binarios, con el cifrado `aes-sha256` solicitado al generarlos, y verificó los 14 archivos por SHA-512. También creó los snapshots `PRE_F2_2026-10-16` y `F2_FINAL_VRRP_OSPF_2026-10-16`. **No se restauró ningún backup de F2 ni el snapshot final.** El export vigente de ISP-1 es el corregido del 19/10, porque el original tenía referencias de interfaz inválidas.
- **Incidencia abierta:** al reiniciarse EDGE el 17/10, su log registró `kernel failure in previous boot` y `router was rebooted without proper shutdown`. La causa no se determinó.

Las pruebas de failover de F2 no son los drills cronometrados de F4. Siguen pendientes F3 (BGP y firewall), F4 (cinco drills y monitoreo) y F5.

## Índice de documentación

- [Memoria del laboratorio](docs/memoria.md)
- [Backlog y seguimiento](backlog.md)
- [Diagrama de diseño F0](docs/diagramas/f0-diseno.md)
- [Evidencias F1 y SSH-MGMT](capturas/F1/)
- [Evidencias F2](capturas/F2/) (índice de figuras en la memoria, sección 7.3)
- [Exports sanitizados de F1](backups/2026-10-09/), [posteriores a SSH-MGMT](backups/2026-10-14/) y [de F2](backups/2026-10-16/)

## Estructura del repositorio

| Directorio | Finalidad |
|---|---|
| `docs/` | Memoria y diagramas del laboratorio. |
| `configs/` | Reservado para configuraciones; actualmente solo contiene `.gitkeep`. |
| `backups/` | Exports públicos sanitizados de los dispositivos. |
| `capturas/` | Capturas y evidencias de implementación y verificación. |
| `runbooks/` | Reservado para procedimientos operativos; actualmente solo contiene `.gitkeep`. |

## Seguridad y respaldos

Los exports públicos están sanitizados. Los backups privados, discos de
dispositivos y credenciales no deben publicarse en GitHub.

Cada hito conserva su propio juego de respaldos, sin sobrescribir los
anteriores: F1, SSH-MGMT, F2 y, cuando se ejecuten, F3 y antes y después
de cada drill de F4.
