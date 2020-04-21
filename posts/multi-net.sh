#!/bin/bash
# (C) Hritik Vijay
# License: GPLv2

tmp=$(mktemp multi-net-ip-XXXX --tmpdir)
TIMEOUT=5
Table=200

_ping(){
	echo "Wait $1 seconds "
	init=$(date +%s)
	curr=$init
	until [ $(($curr-$init)) -ge "$1" ]; do
		curl -s -m $1 "ipecho.net/plain" >> "$tmp"
		echo  >> "$tmp"
		echo -n .
		curr=$(date +%s)
	done
	echo
}

trap "rm $tmp && rm -f $tmp.uniq" EXIT

#----------------------main-------------------#

# Need root
if [ "$(id -u)" -ne 0 ]; then
	echo "[!] Root required"
	exit 
fi

route_cmd="ip route add default scope global "

echo "[*] Scanning interfaces"
# Iterate through each interface and process them
count=0
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

	echo "[*] Processed $IF"
	count=$((count+1))
done < <(ip route list default)

if [ $count -lt 2 ]; then 
	echo "[!] Please connect at least two internet links. Aborted."
	exit
fi

echo "[*] Creating multipath route"
eval "$route_cmd"

echo "[*] Verifying"
_ping $TIMEOUT
sort "$tmp" | uniq > "$tmp.uniq"

if [ $(wc -l "$tmp.uniq" | cut -f 1 -d " ") -gt 1 ]; then
	echo "[*] Success ! Your public IPs: "
	cat "$tmp.uniq"
else
	echo "[!] Failed"
fi
