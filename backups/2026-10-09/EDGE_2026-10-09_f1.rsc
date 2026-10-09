# 2026-10-09 17:23:56 by RouterOS 7.16
# software id = 
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
set [ find default-name=ether4 ] disable-running-check=no
/port
set 0 name=serial0
/ip neighbor discovery-settings
set discover-interface-list=none
/ip address
add address=10.255.0.2/30 comment=ISP-1 interface=ether1 network=10.255.0.0
add address=10.255.0.6/30 comment=ISP-2 interface=ether2 network=10.255.0.4
add address=10.255.0.9/30 comment=CORE-1 interface=ether3 network=10.255.0.8
add address=10.255.0.13/30 comment=CORE-2 interface=ether4 network=\
    10.255.0.12
add address=10.255.255.3 comment="Loopback EDGE" interface=lo network=\
    10.255.255.3
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh disabled=yes
set api disabled=yes
set winbox disabled=yes
set api-ssl disabled=yes
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

