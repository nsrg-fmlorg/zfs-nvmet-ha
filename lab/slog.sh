#!/bin/sh
# Where synchronous writes are kept between a txg and the next, and what
# a power loss on the active controller does to them.
#
#   SLOG_MODE=none    no log device; the ZIL is in the pool on the shared
#                     disks, which the standby can read
#   SLOG_MODE=local   a log device on ctl-a's own disk only; the standby
#                     cannot read it after ctl-a dies
#   SLOG_MODE=mirror  a log mirror of ctl-a's own disk and ctl-b's own
#                     disk, the latter exported to ctl-a over NVMe/TCP;
#                     after ctl-a dies, ctl-b reads its half locally
#
# The host writes O_DIRECT|O_DSYNC blocks through nvmet as in failover.sh.
# ctl-a is killed, ctl-b imports the pool, and every block the host saw
# acknowledged is checked.  "local" is expected to lose some: that is the
# point of measuring it.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
MODE=${SLOG_MODE:-none}
NSUUID=6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001
DEV=/dev/disk/by-id/nvme-uuid.$NSUUID
SLOGNQN=nqn.2026-10.org.fml.nsrg:slog-ctl-b
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
	put "$v" "$HERE/node/nvmet.sh" /home/ubuntu/nvmet.sh
	put "$v" "$HERE/node/blocks.py" /home/ubuntu/blocks.py
done
log "mode $MODE, kernel $(on ctl-a uname -r)"

if [ "$MODE" = mirror ]; then
	log "ctl-b: export its own disk to ctl-a for the log mirror's second half"
	on ctl-b sudo sh -eux <<EOF
modprobe nvmet; modprobe nvmet-tcp
C=/sys/kernel/config/nvmet
mkdir \$C/subsystems/$SLOGNQN
echo 1 > \$C/subsystems/$SLOGNQN/attr_allow_any_host
mkdir \$C/subsystems/$SLOGNQN/namespaces/1
echo /dev/disk/by-id/virtio-local > \$C/subsystems/$SLOGNQN/namespaces/1/device_path
echo 1 > \$C/subsystems/$SLOGNQN/namespaces/1/enable
mkdir \$C/ports/30
echo tcp > \$C/ports/30/addr_trtype
echo ipv4 > \$C/ports/30/addr_adrfam
echo 10.10.0.12 > \$C/ports/30/addr_traddr
echo 4430 > \$C/ports/30/addr_trsvcid
ln -s \$C/subsystems/$SLOGNQN \$C/ports/30/subsystems/$SLOGNQN
EOF
fi

log "ctl-a: pool on the shared disks, log per mode, zvol exported"
on ctl-a sudo sh -eux <<EOF
modprobe nvme-tcp
log=
case $MODE in
local)	log="log /dev/disk/by-id/virtio-local";;
mirror)
	nvme connect -t tcp -a 10.10.0.12 -s 4430 -n $SLOGNQN
	udevadm settle
	r=
	for i in \$(seq 30); do
		for d in /sys/class/nvme/nvme*; do
			[ "\$(cat \$d/subsysnqn)" = $SLOGNQN ] && r=/dev/\${d##*/}n1
		done; true
		[ -n "\$r" ] && [ -e "\$r" ] && break
		sleep 1
	done
	log="log mirror /dev/disk/by-id/virtio-local \$r";;
esac
zpool create -f -o multihost=on -O compression=lz4 tankA mirror \
    /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1 \$log
zpool status tankA
zfs create -V 1G -o volblocksize=16k tankA/vol1
udevadm settle
for i in \$(seq 30); do [ -e /dev/zvol/tankA/vol1 ] && break; sleep 1; done
sh /home/ubuntu/nvmet.sh port 1 10.10.0.11 1 999 optimized
sh /home/ubuntu/nvmet.sh ns /dev/zvol/tankA/vol1
EOF
on ctl-a sudo zpool status tankA > "$OUT/status-before.txt"

log "ctl-b: same subsystem, no namespace yet"
on ctl-b sudo sh /home/ubuntu/nvmet.sh port 2 10.10.0.12 1000 1999 inaccessible

log "host: connect both paths"
on host sudo sh -eux <<EOF
modprobe nvme-tcp
for a in 10.10.0.11 10.10.0.12; do
	nvme connect -t tcp -a \$a -s 4420 -n nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha \
	    --ctrl-loss-tmo=-1 --reconnect-delay=1
done
udevadm settle
for i in \$(seq 30); do [ -e $DEV ] && break; sleep 1; done
EOF

zil() { on ctl-a "cat /proc/spl/kstat/zfs/zil" | awk '$1 ~ /^zil_(commit_count|itx_metaslab_(normal|slog)_count)$/ { print $1, $3 }'; }
zil > "$OUT/zil-before.txt"

log "host: synchronous writer"
on host sudo python3 /home/ubuntu/blocks.py write "$DEV" < /dev/null > "$OUT/writer.log" 2> "$OUT/writer.err" &
writer=$!
sleep 15
zil > "$OUT/zil-during.txt"
before=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)

log "kill ctl-a (power loss) at write index $before"
kill -9 "$(cat "$LAB/ctl-a/qemu.pid")"

log "ctl-b: take over"
rc=0
on ctl-b sudo sh -ux > "$OUT/takeover.txt" 2>&1 <<EOF || rc=$?
now() { cut -d' ' -f1 /proc/uptime; }
t0=\$(now)
# In mirror mode ctl-b's own disk is still exported to the dead ctl-a;
# take it back before ZFS opens it.
C=/sys/kernel/config/nvmet
if [ -d \$C/subsystems/$SLOGNQN ]; then
	rm -f \$C/ports/30/subsystems/$SLOGNQN
	echo 0 > \$C/subsystems/$SLOGNQN/namespaces/1/enable
fi
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1 /dev/disk/by-id/virtio-local; do
	blockdev --rereadpt "\$d"
done
udevadm settle
how=normal
if ! zpool import -d /dev/disk/by-id -f tankA; then
	# Missing log device: the only way in is to discard the ZIL.
	how=discarded-zil
	zpool import -d /dev/disk/by-id -f -m tankA || exit 1
fi
t1=\$(now)
zpool status tankA
udevadm settle
for i in \$(seq 30); do [ -e /dev/zvol/tankA/vol1 ] && break; sleep 1; done
sh /home/ubuntu/nvmet.sh ns /dev/zvol/tankA/vol1
sh /home/ubuntu/nvmet.sh ana 2 optimized
echo "import: \$how"
awk -v a="\$t0" -v b="\$t1" 'BEGIN { printf "import took %.2f s\n", b - a }'
EOF
cat "$OUT/takeover.txt"
[ $rc -eq 0 ] || { echo "takeover failed ($rc)" >&2; kill "$writer" 2>/dev/null || :; exit 1; }

sleep 20
on host "sudo pkill -f 'blocks.py write'" || :
sleep 3
kill "$writer" 2>/dev/null || :

last=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)
on host sudo python3 /home/ubuntu/blocks.py verify "$DEV" "$last" | tee "$OUT/verify.txt"

# Writes per second before the power loss: the cost of where the log is.
rate=$(awk 'NR == 1 { t0 = $2 } $2 - t0 <= 10 { n = $1; t = $2 } END { printf "%.0f", n / (t - t0) }' "$OUT/writer.log")
d=$(paste "$OUT/zil-before.txt" "$OUT/zil-during.txt" | awk '{ printf "%s %d; ", $1, $4 - $2 }')
{
	echo "### SLOG mode: $MODE"
	echo
	echo "- synchronous writes per second before the power loss: $rate"
	echo "- ZIL counters over the first 15 s: $d"
	echo "- $(grep '^import:' "$OUT/takeover.txt")"
	echo "- $(grep '^import took' "$OUT/takeover.txt")"
	echo "- $(cat "$OUT/verify.txt")"
} | tee "$OUT/summary.md"

# none and mirror must keep every acknowledged write; local is expected
# to lose some and is reported, not failed.
[ "$MODE" = local ] || grep -q ', 0 bad' "$OUT/verify.txt"
