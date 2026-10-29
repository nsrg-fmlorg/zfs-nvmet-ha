#!/bin/sh
# Both controllers working: two pools, each normally on its own node.
#
# Each shared disk is split in two partitions, as a dual-ported NVMe drive
# would be split in two namespaces, so that both pools span all the drives:
#
#   tankA  mirror of shared0-part1 and shared1-part1, prefers ctl-a, nsid 1
#   tankB  mirror of shared0-part2 and shared1-part2, prefers ctl-b, nsid 2
#
# Per node, always running: nvmet-subsystem (one NQN, a cntlid range per
# node) and nvmet-port, as in pacemaker.sh.  Each pool moves with its
# namespace as a group.  The host writes to both namespaces; ctl-a loses
# power; tankA moves to ctl-b while tankB's writes should carry on.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
RA_COMMIT=81e937fdb694d39aafbb9ac8ca415b188bb0751b
NQN=nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha
UUID_A=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001
UUID_B=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0002
DEV_A=/dev/disk/by-id/nvme-uuid.$UUID_A
DEV_B=/dev/disk/by-id/nvme-uuid.$UUID_B
mkdir -p "$OUT"

port() { case $1 in ctl-a) echo 2221;; ctl-b) echo 2222;; host) echo 2223;; esac; }
on() {
	v=$1; shift
	ssh -q -i "$LAB/id_ed25519" -p "$(port "$v")" \
	    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	    -o ConnectTimeout=5 ubuntu@127.0.0.1 "$@"
}
put() {
	scp -q -i "$LAB/id_ed25519" -P "$(port "$1")" \
	    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	    "$2" "ubuntu@127.0.0.1:$3"
}
log() { echo "== $(date -u +%T) $*"; }
# Bounded wait for a crm_mon line on a node.
crm_wait() {
	node=$1 pat=$2 tries=$3; n=0
	until on "$node" sudo crm_mon -1 2>/dev/null | grep -q "$pat"; do
		n=$((n + 1))
		[ $n -lt "$tries" ] || { on "$node" sudo crm_mon -1 --failcounts || :; echo "never saw: $pat" >&2; return 1; }
		sleep 2
	done
}

for v in ctl-a ctl-b host; do
	n=0
	until on "$v" test -f /var/lib/cloud/lab-ready 2>/dev/null; do
		n=$((n + 1)); [ $n -lt 120 ] || { echo "$v never became ready" >&2; exit 1; }
		sleep 10
	done
	put "$v" "$HERE/node/blocks.py" /home/ubuntu/blocks.py
done
log "all ready: $(on ctl-a uname -r)"

cat > "$OUT/corosync.conf" <<'EOF'
totem {
	version: 2
	cluster_name: lab
	transport: knet
	crypto_cipher: none
	crypto_hash: none
}
nodelist {
	node {
		ring0_addr: 10.10.0.11
		name: ctl-a
		nodeid: 1
	}
	node {
		ring0_addr: 10.10.0.12
		name: ctl-b
		nodeid: 2
	}
}
quorum {
	provider: corosync_votequorum
	two_node: 1
}
logging {
	to_syslog: yes
	timestamp: on
}
EOF

for v in ctl-a ctl-b; do
	put "$v" "$HERE/patches/resource-agents-nvmet-ana-cntlid.diff" /home/ubuntu/ra.diff
	put "$v" "$OUT/corosync.conf" /home/ubuntu/corosync.conf
	on "$v" sudo sh -eu > "$OUT/$v-setup.txt" 2>&1 <<EOF || { cat "$OUT/$v-setup.txt"; exit 1; }
git clone -q --filter=blob:none https://github.com/ClusterLabs/resource-agents.git /home/ubuntu/ra
cd /home/ubuntu/ra && git checkout -q $RA_COMMIT && git apply /home/ubuntu/ra.diff
# Not every distribution's resource-agents ships the ZFS agent; take it
# from the same checkout where it is missing, and say which was used.
if [ -e /usr/lib/ocf/resource.d/heartbeat/ZFS ]; then echo 'ZFS agent: distribution'
else install -m 0755 heartbeat/ZFS /usr/lib/ocf/resource.d/heartbeat/ZFS; echo 'ZFS agent: checkout'; fi
for a in nvmet-subsystem nvmet-namespace nvmet-port; do
	install -m 0755 heartbeat/\$a /usr/lib/ocf/resource.d/heartbeat/\$a
done
install -m 0644 /home/ubuntu/corosync.conf /etc/corosync/corosync.conf
modprobe nvmet; modprobe nvmet-tcp
systemctl restart corosync
systemctl restart pacemaker
EOF
done

log "ctl-a: split each shared disk in two, a pool on each half, then export both"
on ctl-a sudo sh -eux <<'EOF'
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	printf 'label: gpt\n,2000MiB\n,\n' | sfdisk -q "$d"
done
udevadm settle
zpool create -f -o multihost=on -O compression=lz4 tankA mirror \
    /dev/disk/by-id/virtio-shared0-part1 /dev/disk/by-id/virtio-shared1-part1
zpool create -f -o multihost=on -O compression=lz4 tankB mirror \
    /dev/disk/by-id/virtio-shared0-part2 /dev/disk/by-id/virtio-shared1-part2
zfs create -V 1G -o volblocksize=16k tankA/vol1
zfs create -V 1G -o volblocksize=16k tankB/vol1
zpool export tankA
zpool export tankB
EOF
# ctl-b read the partition tables while the disks were blank (see failover.sh).
on ctl-b sudo sh -eu <<'EOF'
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	blockdev --rereadpt "$d"
done
udevadm settle
EOF

log "wait for both nodes in the cluster"
crm_wait ctl-a 'Online: \[ ctl-a ctl-b \]' 60

cat > "$OUT/cib-nodes.xml" <<EOF
<resources>
  <primitive id="sub-a" class="ocf" provider="heartbeat" type="nvmet-subsystem">
    <instance_attributes id="sub-a-ia">
      <nvpair id="sub-a-nqn" name="nqn" value="$NQN"/>
      <nvpair id="sub-a-serial" name="serial" value="5a46534e564d4554"/>
      <nvpair id="sub-a-min" name="cntlid_min" value="1"/>
      <nvpair id="sub-a-max" name="cntlid_max" value="999"/>
    </instance_attributes>
    <operations><op id="sub-a-mon" name="monitor" interval="10s"/></operations>
  </primitive>
  <primitive id="sub-b" class="ocf" provider="heartbeat" type="nvmet-subsystem">
    <instance_attributes id="sub-b-ia">
      <nvpair id="sub-b-nqn" name="nqn" value="$NQN"/>
      <nvpair id="sub-b-serial" name="serial" value="5a46534e564d4554"/>
      <nvpair id="sub-b-min" name="cntlid_min" value="1000"/>
      <nvpair id="sub-b-max" name="cntlid_max" value="1999"/>
    </instance_attributes>
    <operations><op id="sub-b-mon" name="monitor" interval="10s"/></operations>
  </primitive>
  <primitive id="port-a" class="ocf" provider="heartbeat" type="nvmet-port">
    <instance_attributes id="port-a-ia">
      <nvpair id="port-a-id" name="port_id" value="1"/>
      <nvpair id="port-a-addr" name="addr" value="10.10.0.11"/>
      <nvpair id="port-a-nqns" name="nqns" value="$NQN"/>
    </instance_attributes>
    <operations><op id="port-a-mon" name="monitor" interval="10s"/></operations>
  </primitive>
  <primitive id="port-b" class="ocf" provider="heartbeat" type="nvmet-port">
    <instance_attributes id="port-b-ia">
      <nvpair id="port-b-id" name="port_id" value="2"/>
      <nvpair id="port-b-addr" name="addr" value="10.10.0.12"/>
      <nvpair id="port-b-nqns" name="nqns" value="$NQN"/>
    </instance_attributes>
    <operations><op id="port-b-mon" name="monitor" interval="10s"/></operations>
  </primitive>
</resources>
EOF
cat > "$OUT/cib-nodes-cons.xml" <<'EOF'
<constraints>
  <rsc_location id="sub-a-on-a" rsc="sub-a" node="ctl-a" score="INFINITY"/>
  <rsc_location id="sub-a-not-b" rsc="sub-a" node="ctl-b" score="-INFINITY"/>
  <rsc_location id="port-a-on-a" rsc="port-a" node="ctl-a" score="INFINITY"/>
  <rsc_location id="port-a-not-b" rsc="port-a" node="ctl-b" score="-INFINITY"/>
  <rsc_location id="sub-b-on-b" rsc="sub-b" node="ctl-b" score="INFINITY"/>
  <rsc_location id="sub-b-not-a" rsc="sub-b" node="ctl-a" score="-INFINITY"/>
  <rsc_location id="port-b-on-b" rsc="port-b" node="ctl-b" score="INFINITY"/>
  <rsc_location id="port-b-not-a" rsc="port-b" node="ctl-a" score="-INFINITY"/>
  <rsc_order id="sub-a-then-port-a" first="sub-a" then="port-a"/>
  <rsc_order id="sub-b-then-port-b" first="sub-b" then="port-b"/>
</constraints>
EOF
# One group per pool: the pool and its namespace move together.
pool_group() {
	p=$1 nsid=$2 uuid=$3
	cat <<EOF
  <group id="grp-$p">
    <primitive id="zfs-$p" class="ocf" provider="heartbeat" type="ZFS">
      <instance_attributes id="zfs-$p-ia">
        <nvpair id="zfs-$p-pool" name="pool" value="$p"/>
        <nvpair id="zfs-$p-args" name="importargs" value="-d /dev/disk/by-id"/>
      </instance_attributes>
      <operations>
        <op id="zfs-$p-start" name="start" interval="0s" timeout="120s"/>
        <op id="zfs-$p-stop" name="stop" interval="0s" timeout="60s"/>
        <op id="zfs-$p-mon" name="monitor" interval="5s" timeout="30s"/>
      </operations>
    </primitive>
    <primitive id="ns-$p" class="ocf" provider="heartbeat" type="nvmet-namespace">
      <instance_attributes id="ns-$p-ia">
        <nvpair id="ns-$p-nqn" name="nqn" value="$NQN"/>
        <nvpair id="ns-$p-nsid" name="namespace_id" value="$nsid"/>
        <nvpair id="ns-$p-path" name="backing_path" value="/dev/zvol/$p/vol1"/>
        <nvpair id="ns-$p-uuid" name="uuid" value="$uuid"/>
        <nvpair id="ns-$p-nguid" name="nguid" value="$uuid"/>
      </instance_attributes>
      <operations><op id="ns-$p-mon" name="monitor" interval="10s"/></operations>
    </primitive>
  </group>
EOF
}
pool_group tankA 1 "$UUID_A" > "$OUT/cib-tankA.xml"
pool_group tankB 2 "$UUID_B" > "$OUT/cib-tankB.xml"
echo '<rsc_location id="tankA-prefers-a" rsc="grp-tankA" node="ctl-a" score="100"/>' > "$OUT/cib-tankA-cons.xml"
echo '<rsc_location id="tankB-prefers-b" rsc="grp-tankB" node="ctl-b" score="100"/>' > "$OUT/cib-tankB-cons.xml"
for f in cib-nodes cib-nodes-cons cib-tankA cib-tankA-cons cib-tankB cib-tankB-cons; do
	put ctl-a "$OUT/$f.xml" /home/ubuntu/$f.xml
done

log "configure the per-node resources, then both pools"
on ctl-a sudo sh -eux <<'EOF'
crm_attribute --type crm_config --name stonith-enabled --update false
crm_attribute --type crm_config --name start-failure-is-fatal --update false
cibadmin --create --scope resources --xml-file /home/ubuntu/cib-nodes.xml
cibadmin --create --scope constraints --xml-file /home/ubuntu/cib-nodes-cons.xml
EOF
crm_wait ctl-a 'port-b.*Started ctl-b' 30
on ctl-a sudo sh -eux <<'EOF'
for p in tankA tankB; do
	cibadmin --create --scope resources --xml-file /home/ubuntu/cib-$p.xml
	cibadmin --create --scope constraints --xml-file /home/ubuntu/cib-$p-cons.xml
done
EOF
crm_wait ctl-a 'ns-tankA.*Started ctl-a' 60
crm_wait ctl-a 'ns-tankB.*Started ctl-b' 60
on ctl-a sudo crm_mon -1 | tee "$OUT/crm-before.txt"

log "host: connect both paths, write to both namespaces"
on host sudo sh -eux <<EOF
modprobe nvme-tcp
for a in 10.10.0.11 10.10.0.12; do
	nvme connect -t tcp -a \$a -s 4420 -n $NQN --ctrl-loss-tmo=-1 --reconnect-delay=1
done
udevadm settle
for i in \$(seq 30); do [ -e $DEV_A ] && [ -e $DEV_B ] && break; sleep 1; done
nvme list-subsys
EOF
on host sudo python3 /home/ubuntu/blocks.py write "$DEV_A" < /dev/null > "$OUT/writer-A.log" 2> "$OUT/writer-A.err" &
wa=$!
on host sudo python3 /home/ubuntu/blocks.py write "$DEV_B" < /dev/null > "$OUT/writer-B.log" 2> "$OUT/writer-B.err" &
wb=$!
sleep 15

log "kill ctl-a (power loss)"
kill -9 "$(cat "$LAB/ctl-a/qemu.pid")"
n=0
until on ctl-b sudo crm_mon -1 2>/dev/null | grep -q 'ns-tankA.*Started ctl-b'; do
	n=$((n + 1))
	if [ $n -ge 120 ]; then
		on ctl-b sudo crm_mon -1 --failcounts || :
		echo "tankA never came up on ctl-b" >&2
		kill "$wa" "$wb" 2>/dev/null || :
		exit 1
	fi
	sleep 1
done
on ctl-b sudo crm_mon -1 --failcounts | tee "$OUT/crm-after.txt"
on ctl-b sudo journalctl -o short-monotonic --since '-3min' -u pacemaker -u corosync \
    > "$OUT/ctl-b-journal.txt" 2>&1 || :

sleep 20
on host "sudo pkill -f 'blocks.py write'" || :
sleep 3
kill "$wa" "$wb" 2>/dev/null || :
on host sudo dmesg > "$OUT/host-dmesg.txt" 2>&1 || :

{
	echo "### Two pools, both controllers working; ctl-a loses power"
	echo
	for x in A B; do
		eval dev=\$DEV_$x
		last=$(tail -n 1 "$OUT/writer-$x.log" | cut -d' ' -f1)
		pause=$(awk 'NR > 1 { d = $2 - p; if (d > m) m = d } { p = $2 } END { printf "%.3f", m }' "$OUT/writer-$x.log")
		v=$(on host sudo python3 /home/ubuntu/blocks.py verify "$dev" "$last")
		echo "$v" > "$OUT/verify-$x.txt"
		echo "- tank$x: longest pause $pause s; $v"
	done
	echo "- placement after: $(grep -E 'zfs-tank[AB]' "$OUT/crm-after.txt" | sed 's/^ *\* *//' | tr '\n' ';')"
} | tee "$OUT/summary.md"
grep -q ', 0 bad' "$OUT/verify-A.txt"
grep -q ', 0 bad' "$OUT/verify-B.txt"
