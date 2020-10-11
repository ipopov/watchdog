#!/bin/bash
TAILSCALE_SOFIA=100.82.238.4
TAILSCALE_NYC=100.107.171.12
TUN_SOFIA=192.168.100.2
TUN_NYC=192.168.100.3

FOU_PORT=9000

TUNNEL_NAME=tunudp

ip link add link eth0 name eth0.77 type vlan id 77
ip addr add 192.168.2.1/24 dev eth0.77
ip link set dev eth0.77 up

ip link add link eth0 name eth0.88 type vlan id 88
ip addr add 192.168.3.2/24 dev eth0.88
ip link set dev eth0.88 up

modprobe fou
ip fou add port $FOU_PORT ipproto 4
ip link add name $TUNNEL_NAME type ipip \
  remote $TAILSCALE_SOFIA local $TAILSCALE_NYC \
  encap fou encap-sport auto encap-dport $FOU_PORT

ip addr add $TUN_NYC/31 dev $TUNNEL_NAME
ip link set $TUNNEL_NAME up

ip route add default via $TUN_SOFIA table 1234
ip rule add iif eth0.77 table 1234
iptables -t nat -A POSTROUTING -o tunudp -j MASQUERADE

# An amazing hack to get around the fact that the Sofia exit has an
# edge router that breaks PMTU discovery (by unsetting the 'DF' bit on
# internet ingress packets). So we hack TCP SYN messages, using a neat
# trick from
# https://tldp.org/HOWTO/Adv-Routing-HOWTO/lartc.cookbook.mtu-mss.html.
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1200

echo 1  >  /proc/sys/net/ipv4/ip_forward

#
#iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# NAT outbound traffic from the wireguard client tunnels etc.
iptables -t nat -A POSTROUTING -s 192.168.100.2/31 -o eth0 -j MASQUERADE
