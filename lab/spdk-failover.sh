#!/bin/sh
# lab/failover.sh with SPDK in front of the zvol instead of kernel nvmet.
#
#   ctl-a, ctl-b  nvmf_tgt runs on both from the start, one subsystem NQN,
#                 ANA reporting on (-r), cntlid 1-999 on ctl-a and
#                 1000-1999 on ctl-b, TCP on the node's own 10.10.0.1x
#   ctl-a         imports the pool and exports its zvol as namespace 1
#                 through bdev_uring, with a fixed UUID and NGUID
#   ctl-b         has the subsystem but no namespace until it takes over
#
# The host writes synchronously through native NVMe multipath, ctl-a's
# qemu is killed, ctl-b imports the pool and adds the same namespace.
# Report every pause over half a second and check that every write the
# host saw acknowledged is on the volume.
#
# The namespace lives on one node at a time, so no ANA state changes.
# SPDK announces a namespace added to a live subsystem to its connected
# controllers with a namespace-attribute-changed event: add_ns ends in
# nvmf_subsystem_ns_changed (lib/nvmf/subsystem.c), which raises
# nvmf_ctrlr_async_event_ns_notice (lib/nvmf/ctrlr.c), enabled by default
# (async_event_configuration.bits.ns_attr_notice = 1), as of v26.09.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
NQN=nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha
NSUUID=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001
NSNGUID=6c0a8d2e0f5e4b8a9a523d1c2b7f0001
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
done
put host "$HERE/node/blocks.py" blocks.py
log "all ready: $(on ctl-a uname -r)"

# nvmf_tgt on both controllers, configured per node through /run/spdk.cfg
# so that the setup itself can be one quoted heredoc.
for v in ctl-a ctl-b; do
	case $v in
	ctl-a) addr=10.10.0.11 min=1 max=999;;
	ctl-b) addr=10.10.0.12 min=1000 max=1999;;
	esac
	put "$v" "$LAB/spdk.tar.gz" spdk.tar.gz
	echo "ADDR=$addr MIN=$min MAX=$max NQN=$NQN" | on "$v" sudo tee /run/spdk.cfg > /dev/null
	on "$v" sudo sh -eux > "$OUT/$v-setup.txt" 2>&1 <<'EOF' || { cat "$OUT/$v-setup.txt"; exit 1; }
. /run/spdk.cfg
mkdir -p /opt/spdk && tar -xzf /home/ubuntu/spdk.tar.gz -C /opt/spdk
modprobe zfs
echo 536870912 > /sys/module/zfs/parameters/zfs_arc_max
echo 512 > /proc/sys/vm/nr_hugepages
grep -i hugepages_total /proc/meminfo
LD_LIBRARY_PATH=/opt/spdk/lib nohup /opt/spdk/build/bin/nvmf_tgt -m 0x2 -s 512 -r /run/spdk.sock \
    > /run/nvmf_tgt.log 2>&1 &
for i in $(seq 60); do [ -S /run/spdk.sock ] && break; sleep 1; done
rpc() { python3 /opt/spdk/scripts/rpc.py -s /run/spdk.sock "$@"; }
rpc framework_wait_init || :
rpc nvmf_create_transport -t TCP
rpc nvmf_create_subsystem -a -r -s 5a46534e564d4554 -i $MIN -I $MAX $NQN
rpc nvmf_subsystem_add_listener $NQN -t tcp -f ipv4 -a $ADDR -s 4420
EOF
done

log "ctl-a: create the pool, export its zvol through SPDK"
on ctl-a sudo sh -eux <<EOF
zpool create -f -o multihost=on -O compression=lz4 tankA mirror \
    /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1
zfs create -V 1G -o volblocksize=16k tankA/vol1
udevadm settle
for i in \$(seq 30); do [ -e /dev/zvol/tankA/vol1 ] && break; sleep 1; done
rpc() { python3 /opt/spdk/scripts/rpc.py -s /run/spdk.sock "\$@"; }
rpc bdev_uring_create /dev/zvol/tankA/vol1 zv
rpc nvmf_subsystem_add_ns -n 1 -u $NSUUID -g $NSNGUID $NQN zv
EOF

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
on host sudo python3 /home/ubuntu/blocks.py write "$DEV" < /dev/null > "$OUT/writer.log" 2> "$OUT/writer.err" &
writer=$!
sleep 15
before=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)

log "kill ctl-a (power loss) at write index $before"
kill -9 "$(cat "$LAB/ctl-a/qemu.pid")"

log "ctl-b: import and take over"
rc=0
on ctl-b sudo sh -eux > "$OUT/takeover.txt" 2>&1 <<EOF || rc=$?
now() { cut -d' ' -f1 /proc/uptime; }
t0=\$(now)
# The partition tables ctl-b read at boot are blank (see failover.sh).
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	blockdev --rereadpt "\$d"
done
udevadm settle
t1=\$(now)
zpool import -d /dev/disk/by-id -f tankA
t2=\$(now)
udevadm settle
for i in \$(seq 30); do [ -e /dev/zvol/tankA/vol1 ] && break; sleep 1; done
rpc() { python3 /opt/spdk/scripts/rpc.py -s /run/spdk.sock "\$@"; }
rpc bdev_uring_create /dev/zvol/tankA/vol1 zv
rpc nvmf_subsystem_add_ns -n 1 -u $NSUUID -g $NSNGUID $NQN zv
t3=\$(now)
awk -v a="\$t0" -v b="\$t1" -v c="\$t2" -v d="\$t3" 'BEGIN {
    printf "takeover %.2f s: rescan %.2f s, import %.2f s, export %.2f s\n",
        d - a, b - a, c - b, d - c }'
EOF
cat "$OUT/takeover.txt"
if [ $rc -ne 0 ]; then
	echo "takeover failed ($rc)" >&2
	kill "$writer" 2>/dev/null || :
	exit 1
fi

# Let the writer run on the new path, then stop it.  A writer whose I/O
# is still queued ignores the signal, so drop the ssh instead of waiting.
sleep 20
on host "sudo pkill -f 'blocks.py write'" || :
sleep 3
kill "$writer" 2>/dev/null || :

on host sudo dmesg > "$OUT/host-dmesg.txt" 2>&1 || :
on ctl-b sudo dmesg > "$OUT/ctl-b-dmesg.txt" 2>&1 || :
on ctl-b sudo cat /run/nvmf_tgt.log > "$OUT/ctl-b-nvmf_tgt.log" 2>&1 || :

last=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)
# Every pause over half a second, with when the write that ended it was
# issued, as main's pacemaker.sh reports it.
awk '{ if (NR > 1 && $2 - p > 0.5)
	printf "- pause %.3f s: write %d issued at %.3f, completed at %.3f (previous completion %.3f)\n", $2 - p, $1, $3, $2, p
	p = $2 }' "$OUT/writer.log" > "$OUT/pauses.txt"
first=$(head -n 1 "$OUT/pauses.txt" | sed 's/.*previous completion \([0-9.]*\))/\1/')
lastend=$(tail -n 1 "$OUT/pauses.txt" | sed 's/.*completed at \([0-9.]*\).*/\1/')
outage=$(awk -v a="$first" -v b="$lastend" 'BEGIN { printf "%.3f", b - a }')
log "writer: last acknowledged index $last, outage $outage s"
on host sudo python3 /home/ubuntu/blocks.py verify "$DEV" "$last" | tee "$OUT/verify.txt"

{
	echo "### SPDK failover"
	echo
	echo "- writes before power loss: $before"
	echo "- $(grep '^takeover' "$OUT/takeover.txt")"
	echo "- host I/O outage, last completion before the first pause to the completion ending the last: $outage s"
	cat "$OUT/pauses.txt"
	echo "- $(cat "$OUT/verify.txt")"
} | tee "$OUT/summary.md"
grep -q ', 0 bad' "$OUT/verify.txt"
