#!/bin/bash

hostname=$(hostname)
id=${hostname:1}

if [ -z $(pidof watchfrr) ];
then 
    ip netns add router

    ip link set dev enp6s0 netns router

    ip netns exec router sysctl net.ipv4.conf.all.forwarding=1 > /dev/null
    ip netns exec router sysctl net.ipv4.conf.default.forwarding=1 > /dev/null
    ip netns exec router sysctl net.ipv6.conf.all.forwarding=1 > /dev/null
    ip netns exec router sysctl net.ipv6.conf.default.forwarding=1 > /dev/null

    ip netns exec router ip link set lo up
    ip netns exec router ip link set enp6s0 up

    ip netns exec router ip link add name lo0 type dummy
    ip netns exec router ip link set lo0 up
    ip netns exec router ip address add ${id}.${id}.${id}.${id}/32 dev lo0

    for network in "${@}"
    do
        ip netns exec router ip link add link enp6s0 name vlan${network} type vlan id ${network}
        ip netns exec router ip link set vlan${network} up
        ip netns exec router ip address add 10.0.${network}.${id}/24 dev vlan${network}
    done

    ip netns exec router /usr/lib/frr/frrinit.sh start
fi

ip netns exec router vtysh
