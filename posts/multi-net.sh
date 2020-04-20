#!/bin/bash
# (C) Hritik Vijay
# License: GPLv2

Table=200

route_cmd="ip route add default scope global "
# Iterate through each interface and process them
while read -r line; do
	P=$(echo $line | grep -Eo 'via [0-9\.]+ ' | cut -d " " -f 2)
	IF=$(echo $line | grep -Eo 'dev [A-Za-z0-9]+ ' | cut -d " " -f 2)
	ip=$(ip -br address show dev "$IF" | tr -s ' ' | cut -d " " -f 3)
	IP=${ip%%/*} P_NET=$P # Assumption

	# Init table
	ip route add "$P_NET" dev "$IF" src "$IP" table $Table
	ip route add default via "$P" table $Table 

	# Match connections on proper interfaces
	ip rule add from "$IP" table $Table 

	# add nexthop
	route_cmd="$route_cmd nexthop via $P dev $IF weight 1 "

	# a new table
	Table=$((Table+1))
done < <(ip route list default)

echo $route_cmd
eval "$route_cmd"
