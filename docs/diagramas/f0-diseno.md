# Esquema de diseño F0

Esquema lógico elaborado para F0; conserva un único EDGE como riesgo residual y no representa una topología desplegada ni sustituye la validación de interfaces en GNS3 (F1). Las nueve redes punto a punto son disjuntas.

```mermaid
flowchart TB
  I1["ISP-1<br/>AS 65001<br/>Internet 10.255.255.1/32"]
  I2["ISP-2<br/>AS 65002<br/>Internet 10.255.255.2/32"]
  E["EDGE<br/>AS 65000"]
  C1["CORE-1<br/>OSPF área 0"]
  C2["CORE-2<br/>OSPF área 0"]
  D1["DIST-1<br/>VRID 10 master<br/>VRID 20 backup"]
  D2["DIST-2<br/>VRID 20 master<br/>VRID 10 backup"]
  SU["SW-USERS"]
  SS["SW-SERVERS"]
  PC["PC-USER<br/>192.168.10.100/24"]
  SRV["SRV<br/>192.168.20.100/24"]

  I1 <-->|"eBGP · 10.255.0.0/30"| E
  I2 <-->|"eBGP · 10.255.0.4/30"| E
  E <-->|"OSPF · 10.255.0.8/30"| C1
  E <-->|"OSPF · 10.255.0.12/30"| C2
  C1 <-->|"OSPF · 10.255.0.16/30"| C2
  C1 <-->|"OSPF · 10.255.0.20/30"| D1
  C1 <-->|"OSPF · 10.255.0.24/30"| D2
  C2 <-->|"OSPF · 10.255.0.28/30"| D1
  C2 <-->|"OSPF · 10.255.0.32/30"| D2

  D1 --- SU
  D2 --- SU
  D1 --- SS
  D2 --- SS
  SU --- PC
  SS --- SRV

  SU -. "USERS · VIP 192.168.10.1 · VRID 10" .-> D1
  SS -. "SERVERS · VIP 192.168.20.1 · VRID 20" .-> D2
```

Ambos DIST conectan a ambos switches; las líneas punteadas resaltan el master normal de cada gateway virtual. Las IP de los extremos de enlaces, políticas de routing y nombres de interfaz están en [`../memoria.md`](../memoria.md); las rutas LAN de retorno por BGP y los anuncios por OSPF se implementan/verifican en F3. El esquema no incorpora configuración CLI ni define costos OSPF.
