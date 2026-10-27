# 2026-10-25 14:50:37 by RouterOS 7.16
# software id = 
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/interface list
add comment="F3 FW: enlaces ISP" name=FW-WAN
add comment="F3 FW: enlaces CORE" name=FW-LAN
/ip vrf
add interfaces=ether5 name=MGMT
/port
set 0 name=serial0
/routing ospf instance
add comment="F2 - OSPFv2 area 0" disabled=no name=ospf-v2 originate-default=\
    if-installed out-filter-chain=edge-ospf-out router-id=10.255.255.3
/routing ospf area
add disabled=no instance=ospf-v2 name=backbone-v2
/ip neighbor discovery-settings
set discover-interface-list=none
/interface list member
add comment="F3 FW: ISP-1" interface=ether1 list=FW-WAN
add comment="F3 FW: ISP-2" interface=ether2 list=FW-WAN
add comment="F3 FW: CORE-1" interface=ether3 list=FW-LAN
add comment="F3 FW: CORE-2" interface=ether4 list=FW-LAN
/ip address
add address=10.255.0.2/30 comment=ISP-1 interface=ether1 network=10.255.0.0
add address=10.255.0.6/30 comment=ISP-2 interface=ether2 network=10.255.0.4
add address=10.255.0.9/30 comment=CORE-1 interface=ether3 network=10.255.0.8
add address=10.255.0.13/30 comment=CORE-2 interface=ether4 network=\
    10.255.0.12
add address=10.255.255.3 comment="Loopback EDGE" interface=lo network=\
    10.255.255.3
add address=172.31.250.1/28 comment="Red de gestion aislada" interface=ether5 \
    network=172.31.250.0
/ip firewall address-list
add address=192.168.10.0/24 comment="F3 - EDGE anuncia LAN USERS" list=\
    bgp-lan-out
add address=192.168.20.0/24 comment="F3 - EDGE anuncia LAN SERVERS" list=\
    bgp-lan-out
add address=10.255.0.1 comment="F3 FW: peer ISP-1" list=FW-ISP-PEERS
add address=10.255.0.5 comment="F3 FW: peer ISP-2" list=FW-ISP-PEERS
add address=10.255.0.10 comment="F3 FW: CORE-1" list=FW-CORE-PEERS
add address=10.255.0.14 comment="F3 FW: CORE-2" list=FW-CORE-PEERS
add address=192.168.10.0/24 comment="F3 FW: USERS" list=FW-LAN-INTERNAS
add address=192.168.20.0/24 comment="F3 FW: SERVERS" list=FW-LAN-INTERNAS
/ip firewall filter
add action=accept chain=input comment="MGMT permitir ICMP autorizado" \
    dst-address=172.31.250.1 in-interface=MGMT protocol=icmp src-address=\
    172.31.250.10
add action=accept chain=input comment="MGMT permitir SSH autorizado" \
    dst-address=172.31.250.1 dst-port=22 in-interface=MGMT protocol=tcp \
    src-address=172.31.250.10
add action=drop chain=input comment="MGMT bloquear accesos no autorizados" \
    in-interface=MGMT
add action=accept chain=input comment="F3 FW in: established/related" \
    connection-state=established,related,untracked
add action=accept chain=input comment="F3 FW in: BGP desde ISP" dst-port=179 \
    in-interface-list=FW-WAN protocol=tcp src-address-list=FW-ISP-PEERS
add action=accept chain=input comment="F3 FW in: OSPF desde CORE" \
    in-interface-list=FW-LAN protocol=ospf src-address-list=FW-CORE-PEERS
add action=accept chain=input comment="F3 FW in: ICMP interno" \
    in-interface-list=FW-LAN protocol=icmp
add action=accept chain=input comment="F3 FW in: ICMP desde peers ISP" \
    in-interface-list=FW-WAN protocol=icmp src-address-list=FW-ISP-PEERS
add action=accept chain=forward comment="F3 FW fwd: established/related" \
    connection-state=established,related,untracked
add action=accept chain=forward comment="F3 FW fwd: LAN hacia ISP" \
    connection-state=new out-interface-list=FW-WAN src-address-list=\
    FW-LAN-INTERNAS
add action=drop chain=input comment="F3 FW deny in: invalid" \
    connection-state=invalid
add action=drop chain=input comment="F3 FW deny in: WAN no solicitado" \
    in-interface-list=FW-WAN
add action=drop chain=input comment="F3 FW deny in: resto"
add action=drop chain=forward comment="F3 FW deny fwd: invalid" \
    connection-state=invalid
add action=drop chain=forward comment="F3 FW deny fwd: nuevo desde WAN" \
    connection-state=new in-interface-list=FW-WAN
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=172.31.250.10/32 vrf=MGMT
set api disabled=yes
set winbox disabled=yes
set api-ssl disabled=yes
/ip ssh
set strong-crypto=yes
/routing bgp connection
add as=65000 comment="F3 - eBGP EDGE <-> ISP-1" disabled=no input.filter=\
    edge-in-isp1 local.address=10.255.0.2 .role=ebgp multihop=no name=\
    ebgp-isp1 output.filter-chain=edge-out-isp .network=bgp-lan-out \
    remote.address=10.255.0.1 .as=65001 router-id=10.255.255.3
add as=65000 comment="F3 - eBGP EDGE <-> ISP-2" disabled=no input.filter=\
    edge-in-isp2 local.address=10.255.0.6 .role=ebgp multihop=no name=\
    ebgp-isp2 output.filter-chain=edge-out-isp .network=bgp-lan-out \
    remote.address=10.255.0.5 .as=65002 router-id=10.255.255.3
/routing filter rule
add chain=edge-in-isp1 comment="F3 - ISP-1 in: default" rule=\
    "if (dst == 0.0.0.0/0) { accept }"
add chain=edge-in-isp1 comment="F3 - ISP-1 in: loopback ISP-1" rule=\
    "if (dst == 10.255.255.1/32) { accept }"
add chain=edge-in-isp1 comment="F3 - ISP-1 in: rechazar resto" rule=reject
add chain=edge-out-isp comment="F3 - salida a ISP: solo LAN USERS/SERVERS" \
    rule="if (dst == 192.168.10.0/24 || dst == 192.168.20.0/24) { accept }"
add chain=edge-out-isp comment=\
    "F3 - salida a ISP: rechazar resto (MGMT, /30, loopbacks)" rule=reject
add chain=edge-in-isp2 comment="F3 - ISP-2 in: default" rule=\
    "if (dst == 0.0.0.0/0) { accept }"
add chain=edge-in-isp2 comment="F3 - ISP-2 in: loopback ISP-2" rule=\
    "if (dst == 10.255.255.2/32) { accept }"
add chain=edge-in-isp2 comment="F3 - ISP-2 in: rechazar resto" rule=reject
add chain=edge-ospf-out comment="F3 - OSPF out: solo loopbacks ISP" rule=\
    "if (dst == 10.255.255.1/32 || dst == 10.255.255.2/32) { accept }"
add chain=edge-ospf-out comment="F3 - OSPF out: rechazar resto de BGP" rule=\
    reject
/routing ospf interface-template
add area=backbone-v2 auth=md5 auth-id=1 auth-key="REDACTED_F3_DO_NOT_USE" comment=\
    "F2 - EDGE CORE-1 OSPF" disabled=no interfaces=ether3 type=ptp
add area=backbone-v2 auth=md5 auth-id=1 auth-key="REDACTED_F3_DO_NOT_USE" comment=\
    "F2 - EDGE CORE-2 OSPF" disabled=no interfaces=ether4 type=ptp
add area=backbone-v2 comment="F2 - EDGE loopback OSPF passive" disabled=no \
    interfaces=lo passive
/system identity
set name=EDGE
/system note
set show-at-login=no
/tool bandwidth-server
set enabled=no
/tool mac-server
set allowed-interface-list=none
/tool mac-server mac-winbox
set allowed-interface-list=none
/tool mac-server ping
set enabled=no
/user group
add name=monitor policy="ssh,read,!local,!telnet,!ftp,!reboot,!write,!policy,!\
    test,!winbox,!password,!web,!sniff,!sensitive,!api,!romon,!rest-api"
