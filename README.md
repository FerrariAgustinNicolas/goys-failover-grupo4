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
| F1 | Topología, hardening y backup | 09/10/2026 | Implementación y documentación integradas al repositorio; pendientes operativos detallados abajo. |
| F2 | VRRP y OSPF | 16/10/2026 | Pendiente de ejecución. |
| F3 | BGP y firewall | 16/10/2026 | Pendiente de ejecución. |
| F4 | Drills y monitoreo | 20/10/2026 | Pendiente de ejecución. |
| F5 | Memoria y defensa | 23/10/2026 | Pendiente de finalización. |

F1 no se declara aprobada por la cátedra ni cerrada operativamente:
permanecen pendientes los procedimientos internos de backup/restore
(incluida la prueba de restauración) y el acceso de gestión restringido.

## Índice de documentación

- [Memoria del laboratorio](docs/memoria.md)
- [Backlog y seguimiento](backlog.md)
- [Diagrama de diseño F0](docs/diagramas/f0-diseno.md)
- [Evidencias F1](capturas/F1/)
- [Exports públicos sanitizados de F1](backups/2026-10-09/)

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
