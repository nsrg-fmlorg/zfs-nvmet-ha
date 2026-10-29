#!/bin/sh
# Scenario: the same power loss as failover.sh, but Pacemaker does the
# takeover.
#
#   per node, always running   nvmet-subsystem (one NQN, cntlid range per
#                              node) and nvmet-port (the node's address)
#   follows the pool           ZFS (tankA) and nvmet-namespace (its zvol)
#
# The namespace exists only where the pool is imported, so the host sees
# it on one path at a time and no ANA state has to change; what the two
# nodes do need is disjoint controller ID ranges.
#
# The nvmet agents are ClusterLabs/resource-agents at RA_COMMIT with
# lab/patches/resource-agents-nvmet-ana-cntlid.diff applied.  Fencing is
# off: this measures the takeover path, and multihost=on refuses a second
# import of the pool.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
RA_COMMIT=81e937fdb694d39aafbb9ac8ca415b188bb0751b
NQN=nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha
NSUUID=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001
DEV=/dev/disk/by-id/nvme-uuid.$NSUUID
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

for v in ctl-a ctl-b host; do
	n=0
	until on "$v" test -f /var/lib/cloud/lab-ready 2>/dev/null; do
		n=$((n + 1)); [ $n -lt 120 ] || { echo "$v never became ready" >&2; exit 1; }
		sleep 10
	done
	put "$v" "$HERE/node/blocks.py" /tmp/blocks.py
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
	put "$v" "$HERE/patches/resource-agents-nvmet-ana-cntlid.diff" /tmp/ra.diff
	put "$v" "$OUT/corosync.conf" /tmp/corosync.conf
	on "$v" sudo sh -eu > "$OUT/$v-setup.txt" 2>&1 <<EOF || { cat "$OUT/$v-setup.txt"; exit 1; }
git clone -q --filter=blob:none https://github.com/ClusterLabs/resource-agents.git /tmp/ra
cd /tmp/ra && git checkout -q $RA_COMMIT && git apply /tmp/ra.diff
# Not every distribution's resource-agents ships the ZFS agent; take it
# from the same checkout where it is missing, and say which was used.
if [ -e /usr/lib/ocf/resource.d/heartbeat/ZFS ]; then echo 'ZFS agent: distribution'
else install -m 0755 heartbeat/ZFS /usr/lib/ocf/resource.d/heartbeat/ZFS; echo 'ZFS agent: checkout'; fi
for a in nvmet-subsystem nvmet-namespace nvmet-port; do
	install -m 0755 heartbeat/\$a /usr/lib/ocf/resource.d/heartbeat/\$a
done
install -m 0644 /tmp/corosync.conf /etc/corosync/corosync.conf
modprobe nvmet; modprobe nvmet-tcp
systemctl restart corosync
systemctl restart pacemaker
EOF
done

log "ctl-a: create the pool, then export it for Pacemaker to import"
on ctl-a sudo sh -eux <<'EOF'
zpool create -f -o multihost=on -O compression=lz4 tankA mirror \
    /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1
zfs create -V 1G -o volblocksize=16k tankA/vol1
zpool export tankA
EOF
# ctl-b read the partition tables while the disks were blank (see failover.sh).
on ctl-b sudo sh -eu <<'EOF'
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	blockdev --rereadpt "$d"
done
udevadm settle
EOF

log "wait for both nodes in the cluster"
n=0
until on ctl-a sudo crm_mon -1 2>/dev/null | grep -q 'Online: \[ ctl-a ctl-b \]'; do
	n=$((n + 1)); [ $n -lt 60 ] || { on ctl-a sudo crm_mon -1 || :; echo "cluster never formed" >&2; exit 1; }
	sleep 5
done

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
cat > "$OUT/cib-pool.xml" <<EOF
  <group id="grp-tankA">
    <primitive id="zfs-tankA" class="ocf" provider="heartbeat" type="ZFS">
      <instance_attributes id="zfs-tankA-ia">
        <nvpair id="zfs-tankA-pool" name="pool" value="tankA"/>
        <nvpair id="zfs-tankA-args" name="importargs" value="-d /dev/disk/by-id"/>
      </instance_attributes>
      <operations>
        <op id="zfs-tankA-start" name="start" interval="0s" timeout="120s"/>
        <op id="zfs-tankA-stop" name="stop" interval="0s" timeout="60s"/>
        <op id="zfs-tankA-mon" name="monitor" interval="5s" timeout="30s"/>
      </operations>
    </primitive>
    <primitive id="ns-tankA" class="ocf" provider="heartbeat" type="nvmet-namespace">
      <instance_attributes id="ns-tankA-ia">
        <nvpair id="ns-tankA-nqn" name="nqn" value="$NQN"/>
        <nvpair id="ns-tankA-nsid" name="namespace_id" value="1"/>
        <nvpair id="ns-tankA-path" name="backing_path" value="/dev/zvol/tankA/vol1"/>
        <nvpair id="ns-tankA-uuid" name="uuid" value="$NSUUID"/>
        <nvpair id="ns-tankA-nguid" name="nguid" value="$NSUUID"/>
      </instance_attributes>
      <operations><op id="ns-tankA-mon" name="monitor" interval="10s"/></operations>
    </primitive>
  </group>
EOF
# A second cibadmin --create takes the element to add, not its section:
# <resources> again would nest inside the existing one and fail the schema.
cat > "$OUT/cib-pool-cons.xml" <<'EOF'
<rsc_location id="tankA-prefers-a" rsc="grp-tankA" node="ctl-a" score="100"/>
EOF
for f in cib-nodes cib-nodes-cons cib-pool cib-pool-cons; do put ctl-a "$OUT/$f.xml" /tmp/$f.xml; done

log "configure the per-node resources, then the pool"
on ctl-a sudo sh -eux <<'EOF'
crm_attribute --type crm_config --name stonith-enabled --update false
# A start that fails is retried rather than banning the node: the zvol
# device can appear a moment after the import returns.
crm_attribute --type crm_config --name start-failure-is-fatal --update false
cibadmin --create --scope resources --xml-file /tmp/cib-nodes.xml
cibadmin --create --scope constraints --xml-file /tmp/cib-nodes-cons.xml
EOF
n=0
until on ctl-a sudo crm_mon -1 2>/dev/null | grep -q 'port-b.*Started ctl-b'; do
	n=$((n + 1)); [ $n -lt 30 ] || { on ctl-a sudo crm_mon -1 || :; echo "per-node resources never started" >&2; exit 1; }
	sleep 2
done
on ctl-a sudo sh -eux <<'EOF'
cibadmin --create --scope resources --xml-file /tmp/cib-pool.xml
cibadmin --create --scope constraints --xml-file /tmp/cib-pool-cons.xml
EOF
n=0
until on ctl-a sudo crm_mon -1 2>/dev/null | grep -q 'ns-tankA.*Started ctl-a'; do
	n=$((n + 1)); [ $n -lt 60 ] || { on ctl-a sudo crm_mon -1 || :; echo "pool never started on ctl-a" >&2; exit 1; }
	sleep 2
done
on ctl-a sudo crm_mon -1 | tee "$OUT/crm-before.txt"
on ctl-a sudo crm_mon -1 --failcounts > "$OUT/failcounts-before.txt" 2>&1 || :

log "host: connect both paths"
on host sudo sh -eux <<EOF
modprobe nvme-tcp
for a in 10.10.0.11 10.10.0.12; do
	nvme connect -t tcp -a \$a -s 4420 -n $NQN --ctrl-loss-tmo=-1 --reconnect-delay=1
done
udevadm settle
for i in \$(seq 30); do [ -e $DEV ] && break; sleep 1; done
nvme list-subsys
EOF
on host sudo nvme list-subsys > "$OUT/subsys-before.txt"

log "host: start synchronous writer"
on host sudo python3 /tmp/blocks.py write "$DEV" < /dev/null > "$OUT/writer.log" 2> "$OUT/writer.err" &
writer=$!
sleep 15
before=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)

log "kill ctl-a (power loss) at write index $before"
t_kill=$(on ctl-b "cut -d' ' -f1 /proc/uptime")
kill -9 "$(cat "$LAB/ctl-a/qemu.pid")"

# Bounded wait for Pacemaker on ctl-b to bring the namespace up.
n=0
until on ctl-b sudo crm_mon -1 2>/dev/null | grep -q 'ns-tankA.*Started ctl-b'; do
	n=$((n + 1))
	if [ $n -ge 120 ]; then
		on ctl-b sudo crm_mon -1 --failcounts || :
		echo "takeover did not complete" >&2
		kill "$writer" 2>/dev/null || :
		exit 1
	fi
	sleep 1
done
t_up=$(on ctl-b "cut -d' ' -f1 /proc/uptime")
on ctl-b sudo crm_mon -1 --failcounts | tee "$OUT/crm-after.txt"
# Pacemaker's own account of the takeover, and the import's.
on ctl-b sudo journalctl -o short-monotonic --since '-3min' -u pacemaker -u corosync \
    > "$OUT/ctl-b-journal.txt" 2>&1 || :
on ctl-b sudo cat /proc/spl/kstat/zfs/dbgmsg > "$OUT/ctl-b-dbgmsg.txt" 2>&1 || :

sleep 20
on host "sudo pkill -f 'blocks.py write'" || :
sleep 3
kill "$writer" 2>/dev/null || :

# Kernel logs, on the same monotonic base as the writer's times (dmesg's
# raw seconds since boot), for what the NVMe host did with in-flight I/O.
on host sudo dmesg > "$OUT/host-dmesg.txt" 2>&1 || :
on ctl-b sudo dmesg > "$OUT/ctl-b-dmesg.txt" 2>&1 || :

last=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)
# Every pause over half a second, with when the write that ended it was
# issued.  A single "longest gap" hid that one write completed in the
# middle of the outage and split it in two.
awk '{ if (NR > 1 && $2 - p > 0.5)
	printf "- pause %.3f s: write %d issued at %.3f, completed at %.3f (previous completion %.3f)\n", $2 - p, $1, $3, $2, p
	p = $2 }' "$OUT/writer.log" > "$OUT/pauses.txt"
first=$(head -n 1 "$OUT/pauses.txt" | sed 's/.*previous completion \([0-9.]*\))/\1/')
lastend=$(tail -n 1 "$OUT/pauses.txt" | sed 's/.*completed at \([0-9.]*\).*/\1/')
outage=$(awk -v a="$first" -v b="$lastend" 'BEGIN { printf "%.3f", b - a }')
log "writer: last acknowledged index $last, outage $outage s"
cat "$OUT/pauses.txt"
on host sudo python3 /tmp/blocks.py verify "$DEV" "$last" | tee "$OUT/verify.txt"

{
	echo "### Pacemaker failover"
	echo
	echo "- writes before power loss: $before"
	echo "- $(awk -v a="$t_kill" -v b="$t_up" 'BEGIN { printf "power loss to namespace seen started by polling crm_mon (upper bound): %.2f s", b - a }')"
	echo "- host I/O outage, last completion before the first pause to the completion ending the last: $outage s"
	cat "$OUT/pauses.txt"
	echo "- $(cat "$OUT/verify.txt")"
	echo "- failcounts on ctl-b: $(grep -i -A3 'fail' "$OUT/crm-after.txt" | grep -vi 'migration summary' | tr '\n' ' ' | cut -c1-200)"
} | tee "$OUT/summary.md"
grep -q ', 0 bad' "$OUT/verify.txt"
