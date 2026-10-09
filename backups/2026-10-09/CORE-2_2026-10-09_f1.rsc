# 2026-10-09 17:04:37 by RouterOS 7.16
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
add address=10.255.0.14/30 comment=EDGE interface=ether1 network=10.255.0.12
add address=10.255.0.18/30 comment=CORE-1 interface=ether2 network=\
    10.255.0.16
add address=10.255.0.29/30 comment=DIST-1 interface=ether3 network=\
    10.255.0.28
add address=10.255.0.33/30 comment=DIST-2 interface=ether4 network=\
    10.255.0.32
add address=10.255.255.5 comment="Loopback CORE-2" interface=lo network=\
    10.255.255.5
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh disabled=yes
set api disabled=yes
set winbox disabled=yes
set api-ssl disabled=yes
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

