#!/bin/sh
# Run on the killed node: once a new CIB manager is up (not the one that
# was running before the kill, given by its pid), make N configuration
# changes to the node's own CIB while it is still alone.
#   usage: node-bumps.sh N OLD_PID
n=$1 old=$2
for t in $(seq 150); do
	pid=$(pidof pacemaker-based || :)
	if [ -n "$pid" ] && [ "$pid" != "$old" ] && cibadmin -Q -l > /dev/null 2>&1; then
		break
	fi
	sleep 0.2
done
echo "pacemaker-based $old -> ${pid:-none} after $t tries"
for i in $(seq "$n"); do
	crm_attribute --type crm_config --name lab-node-bump --update "$i"
done
logger -t lab "=== $n changes on the node's own CIB ==="
cibadmin -Q -l | grep -m1 -o '<cib [^>]*>'
