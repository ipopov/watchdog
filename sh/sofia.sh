#!/bin/bash
TAILSCALE_SOFIA=100.82.238.4
TAILSCALE_NYC=100.107.171.12
TUN_SOFIA=192.168.100.2
TUN_NYC=192.168.100.3

FOU_PORT=9000

TUNNEL_NAME=tunudp

echo 1  >  /proc/sys/net/ipv4/ip_forward

modprobe fou
ip fou add port $FOU_PORT ipproto 4
ip link add name $TUNNEL_NAME type ipip \
  remote $TAILSCALE_NYC local $TAILSCALE_SOFIA \
  encap fou encap-sport auto encap-dport $FOU_PORT

ip addr add $TUN_SOFIA/31 dev $TUNNEL_NAME
ip link set $TUNNEL_NAME up

iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

# Wireguard client tunnels
ip rule add from 192.168.2.4/30 table 555
ip route add table 555 default via 192.168.100.3 dev tunudp
iptables -t nat -A POSTROUTING -s 192.168.2.4/30 -o tunudp -j MASQUERADE

#ip route add default via $TUN_NYC table 1234
#ip rule add iif wlan0 table 1234
#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
