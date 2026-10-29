# 2026-10-25 14:45:21 by RouterOS 7.16
# software id = 
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/ip vrf
add interfaces=ether2 name=MGMT
/port
set 0 name=serial0
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.255.0.1/30 comment=EDGE interface=ether1 network=10.255.0.0
add address=10.255.255.1 comment="Loopback ISP-1" interface=lo network=\
    10.255.255.1
add address=172.31.250.2/28 comment="Red de gestion aislada" interface=ether2 \
    network=172.31.250.0
/ip firewall address-list
add address=10.255.255.1 comment="F3 - ISP-1 anuncia su loopback" list=\
    bgp-isp1-out
/ip firewall filter
add action=accept chain=input comment="MGMT permitir ICMP autorizado" \
    dst-address=172.31.250.2 in-interface=MGMT protocol=icmp src-address=\
    172.31.250.10
add action=accept chain=input comment="MGMT permitir SSH autorizado" \
    dst-address=172.31.250.2 dst-port=22 in-interface=MGMT protocol=tcp \
    src-address=172.31.250.10
add action=drop chain=input comment="MGMT bloquear accesos no autorizados" \
    in-interface=MGMT
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
add as=65001 comment="F3 - eBGP ISP-1 <-> EDGE" disabled=no input.filter=\
    isp1-in-edge local.address=10.255.0.1 .role=ebgp multihop=no name=\
    ebgp-edge output.default-originate=always .filter-chain=isp1-out-edge \
    .network=bgp-isp1-out remote.address=10.255.0.2 .as=65000 router-id=\
    10.255.255.1
/routing filter rule
add chain=isp1-in-edge comment="F3 - ISP-1 acepta solo LAN de EDGE" rule=\
    "if (dst == 192.168.10.0/24 || dst == 192.168.20.0/24) { accept }"
add chain=isp1-in-edge comment="F3 - ISP-1 in: rechazar resto" rule=reject
add chain=isp1-out-edge comment="F3 - ISP-1 out: default y loopback" rule=\
    "if (dst == 0.0.0.0/0 || dst == 10.255.255.1/32) { accept }"
add chain=isp1-out-edge comment="F3 - ISP-1 out: rechazar resto" rule=reject
/system identity
set name=ISP-1
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
