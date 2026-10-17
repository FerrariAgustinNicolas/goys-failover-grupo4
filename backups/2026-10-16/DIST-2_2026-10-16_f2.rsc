# 2026-10-16 23:53:12 by RouterOS 7.16
# software id = 
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
set [ find default-name=ether5 ] disable-running-check=no
/interface vrrp
add authentication=simple comment="F2 - SERVERS - DIST-2 master preferido" \
    interface=ether4 name=vrrp-servers-20 priority=150 version=2 vrid=20
add authentication=simple comment="F2 - USERS - DIST-2 backup preferido" \
    interface=ether3 name=vrrp-users-10 version=2 vrid=10
/ip vrf
add interfaces=ether5 name=MGMT
/port
set 0 name=serial0
/routing ospf instance
add comment="F2 - OSPFv2 area 0" disabled=no name=ospf-v2 router-id=\
    10.255.255.7
/routing ospf area
add disabled=no instance=ospf-v2 name=backbone-v2
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.255.0.26/30 comment=CORE-1 interface=ether1 network=\
    10.255.0.24
add address=10.255.0.34/30 comment=CORE-2 interface=ether2 network=\
    10.255.0.32
add address=192.168.10.3/24 comment="LAN USERS" interface=ether3 network=\
    192.168.10.0
add address=192.168.20.3/24 comment="LAN SERVERS" interface=ether4 network=\
    192.168.20.0
add address=10.255.255.7 comment="Loopback DIST-2" interface=lo network=\
    10.255.255.7
add address=172.31.250.7/28 comment="Red de gestion aislada" interface=ether5 \
    network=172.31.250.0
add address=192.168.10.1 comment="F2 - VIP USERS VRID 10" interface=\
    vrrp-users-10 network=192.168.10.1
add address=192.168.20.1 comment="F2 - VIP SERVERS VRID 20" interface=\
    vrrp-servers-20 network=192.168.20.1
/ip firewall filter
add action=accept chain=input comment="MGMT permitir ICMP autorizado" \
    dst-address=172.31.250.7 in-interface=MGMT protocol=icmp src-address=\
    172.31.250.10
add action=accept chain=input comment="MGMT permitir SSH autorizado" \
    dst-address=172.31.250.7 dst-port=22 in-interface=MGMT protocol=tcp \
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
/routing ospf interface-template
add area=backbone-v2 auth=md5 auth-id=1 auth-key="REDACTED_F2_DO_NOT_USE" comment=\
    "F2 - DIST-2 CORE-1 OSPF" disabled=no interfaces=ether1 type=ptp
add area=backbone-v2 auth=md5 auth-id=1 auth-key="REDACTED_F2_DO_NOT_USE" comment=\
    "F2 - DIST-2 CORE-2 OSPF" disabled=no interfaces=ether2 type=ptp
add area=backbone-v2 comment="F2 - DIST-2 USERS OSPF passive" disabled=no \
    interfaces=ether3 passive
add area=backbone-v2 comment="F2 - DIST-2 SERVERS OSPF passive" disabled=no \
    interfaces=ether4 passive
add area=backbone-v2 comment="F2 - DIST-2 loopback OSPF passive" disabled=no \
    interfaces=lo passive
/system identity
set name=DIST-2
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
