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
| F2 | VRRP y OSPF | 16/10/2026 | Pendiente de ejecución. |
| F3 | BGP y firewall | 16/10/2026 | Pendiente de ejecución. |
| F4 | Drills y monitoreo | 20/10/2026 | Pendiente de ejecución. |
| F5 | Memoria y defensa | 23/10/2026 | Pendiente de finalización. |

## Estado actual del laboratorio

La topología corre en GNS3 con siete routers MikroTik CHR (RouterOS 7.16): ISP-1, ISP-2, EDGE, CORE-1, CORE-2, DIST-1 y DIST-2, más dos switches y dos hosts (PC-USER y SRV). Tienen aplicados el direccionamiento del IPAM, las loopbacks y el hardening de F1. VRRP, OSPF, BGP y el firewall de EDGE todavía no están configurados.

- **Cierre de F1 (09/10):** SSH quedó deshabilitado en los siete routers y la administración se hacía solo por la consola de GNS3. Exports en [`backups/2026-10-09/`](backups/2026-10-09/).
- **Red de gestión SSH-MGMT (14/10, posterior a F1):** cada router tiene una interfaz en la red aislada `172.31.250.0/28`, dentro de una VRF `MGMT`. SSH solo acepta conexiones desde `172.31.250.10/32`; R1 comprobó el acceso autorizado y el rechazo desde otra dirección en los siete routers. Exports en [`backups/2026-10-14/`](backups/2026-10-14/) (PR #18 a #21).
- **Backups binarios:** hay dos juegos cifrados de los siete routers, uno de F1 (10 y 13/10) y otro posterior a SSH-MGMT (15/10). Se guardan fuera del repositorio. En cada juego se restauró ISP-1 en un proyecto aislado; el restore del 16/10 requirió corregir a mano las referencias de interfaces. Los otros seis binarios de cada juego no se restauraron.

Quedan pendientes F2 a F5, sus backups por hito y el procedimiento privado de recuperación de credenciales. El detalle está en la memoria y en el backlog.

## Índice de documentación

- [Memoria del laboratorio](docs/memoria.md)
- [Backlog y seguimiento](backlog.md)
- [Diagrama de diseño F0](docs/diagramas/f0-diseno.md)
- [Evidencias F1 y SSH-MGMT](capturas/F1/)
- [Exports sanitizados de F1](backups/2026-10-09/) y [posteriores a SSH-MGMT](backups/2026-10-14/)

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
anteriores: F1, SSH-MGMT y, cuando se ejecuten, F2, F3 y antes y después
de cada drill de F4.
