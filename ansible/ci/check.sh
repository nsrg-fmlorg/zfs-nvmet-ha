#!/bin/sh
# What the controllers should look like after site.yml or MANUAL.md:
# both nodes online, each pool started on the node it prefers, and a
# host that reaches each namespace optimized through its owner, with a
# path to both controllers.  Runs where "ssh ctl-a" and "ssh host" work.
set -eu

NQN=nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha

ssh ctl-a sudo crm_mon -1 | tee crm.txt
grep -q 'Online: \[ ctl-a ctl-b \]' crm.txt
grep -q 'ns-tankA.*Started ctl-a' crm.txt
grep -q 'ns-tankB.*Started ctl-b' crm.txt

# Paths and their ANA states are read from sysfs rather than from
# nvme-cli's listing, whose format differs between versions.
ssh host sudo sh -eu <<EOF
modprobe nvme-tcp
connected() {
	for c in /sys/class/nvme/nvme*; do
		[ "\$(cat \$c/subsysnqn)" = $NQN ] && grep -q "traddr=\$1," \$c/address && return 0
	done; return 1
}
for a in 10.10.0.11 10.10.0.12; do
	connected \$a || nvme connect -t tcp -a \$a -s 4420 -n $NQN --ctrl-loss-tmo=-1 > /dev/null
done
udevadm settle
fail=0
n=0
for c in /sys/class/nvme/nvme*; do [ "\$(cat \$c/subsysnqn)" = $NQN ] && n=\$((n + 1)); done
[ \$n -eq 2 ] && echo "ok   two controllers in the subsystem" || { echo "FAIL \$n controllers"; fail=1; }
for x in tankA:10.10.0.11:6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001 tankB:10.10.0.12:6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0002; do
	p=\${x%%:*}; r=\${x#*:}; ip=\${r%%:*}; uuid=\${r#*:}
	i=0
	until [ -e /dev/disk/by-id/nvme-uuid.\$uuid ]; do
		i=\$((i + 1)); [ \$i -lt 30 ] || break
		sleep 1
	done
	head=\$(basename "\$(readlink -f /dev/disk/by-id/nvme-uuid.\$uuid 2> /dev/null)")
	[ -d /sys/block/\$head ] || { echo "FAIL \$p: no namespace \$uuid"; fail=1; continue; }
	got=
	for path in /sys/block/\$head/multipath/*; do
		pn=\${path##*/}; ctrl=\$(echo \$pn | sed 's/^nvme[0-9]*c\([0-9]*\)n.*/nvme\1/')
		echo "\$p: \$pn via \$(cat /sys/class/nvme/\$ctrl/address | cut -d, -f1) \$(cat \$path/ana_state)"
		grep -q "traddr=\$ip," /sys/class/nvme/\$ctrl/address && got=\$(cat \$path/ana_state)
	done
	[ "\$got" = optimized ] && echo "ok   \$p optimized through \$ip" ||
	    { echo "FAIL \$p through \$ip: '\$got'"; fail=1; }
done
exit \$fail
EOF
