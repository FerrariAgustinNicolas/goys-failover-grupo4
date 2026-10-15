# 2026-10-15 02:14:27 by RouterOS 7.16
# software id = 
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/ip vrf
add interfaces=ether5 name=MGMT
/port
set 0 name=serial0
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.255.0.14/30 comment=EDGE interface=ether1 network=10.255.0.12
add address=10.255.0.18/30 comment=CORE-1 interface=ether2 network=\
    10.255.0.16
add address=10.255.0.29/30 comment=DIST-1 interface=ether3 network=\
    10.255.0.28
add address=10.255.0.33/30 comment=DIST-2 interface=ether4 network=\
    10.255.0.32
add address=10.255.255.5 comment="Loopback CORE-2" interface=lo network=\
    10.255.255.5
add address=172.31.250.5/28 comment="Red de gestion aislada" interface=ether5 \
    network=172.31.250.0
/ip firewall filter
add action=accept chain=input comment="MGMT permitir ICMP autorizado" \
    dst-address=172.31.250.5 in-interface=MGMT protocol=icmp src-address=\
    172.31.250.10
add action=accept chain=input comment="MGMT permitir SSH autorizado" \
    dst-address=172.31.250.5 dst-port=22 in-interface=MGMT protocol=tcp \
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
/system identity
set name=CORE-2
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

