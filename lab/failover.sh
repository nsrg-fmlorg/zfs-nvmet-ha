#!/bin/sh
# Scenario: ctl-a serves a zvol over NVMe/TCP, the host writes synchronously
# through native NVMe multipath, ctl-a loses power (qemu killed), and ctl-b
# takes the pool over.  Report the I/O pause the host saw and check that
# every write the host had acknowledged is still on the volume.
set -eu

LAB=${LAB:-$(pwd)/work}
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$LAB/out}
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

# Bounded wait for cloud-init on all three; 20 minutes covers the apt runs.
for v in ctl-a ctl-b host; do
	n=0
	until on "$v" test -f /var/lib/cloud/lab-ready 2>/dev/null; do
		n=$((n + 1)); [ $n -lt 120 ] || { echo "$v never became ready" >&2; exit 1; }
		sleep 10
	done
	log "$v ready: $(on "$v" uname -r)"
	put "$v" "$HERE/node/nvmet.sh" /tmp/nvmet.sh
	put "$v" "$HERE/node/blocks.py" /tmp/blocks.py
done

# MMP settings under test.  The importer's wait is computed from the
# interval and fail count the previous owner stamped into its uberblocks
# (spa_activity_check_duration), so ctl-a's values are the ones that
# count; ctl-b gets the same so it behaves the same once it owns the pool.
MMP_INTERVAL=${MMP_INTERVAL:-1000}
MMP_FAIL=${MMP_FAIL:-10}
for v in ctl-a ctl-b; do
	on "$v" sudo sh -eu <<EOF
modprobe zfs
echo $MMP_INTERVAL > /sys/module/zfs/parameters/zfs_multihost_interval
echo $MMP_FAIL > /sys/module/zfs/parameters/zfs_multihost_fail_intervals
echo 1 > /sys/module/zfs/parameters/zfs_dbgmsg_enable
echo 0 > /proc/spl/kstat/zfs/dbgmsg
EOF
done
log "MMP interval ${MMP_INTERVAL} ms, fail intervals ${MMP_FAIL}"

log "ctl-a: create pool on the shared disks, export the zvol"
on ctl-a sudo sh -eux <<'EOF'
zpool create -f -o multihost=on -O compression=lz4 tankA mirror \
    /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1
zfs create -V 1G -o volblocksize=16k tankA/vol1
udevadm settle
sh /tmp/nvmet.sh port 1 10.10.0.11 1 999 optimized
sh /tmp/nvmet.sh ns /dev/zvol/tankA/vol1
EOF

log "ctl-b: same subsystem, no namespace yet, ANA inaccessible"
on ctl-b sudo sh /tmp/nvmet.sh port 2 10.10.0.12 1000 1999 inaccessible

log "host: connect both paths"
on host sudo sh -eux <<EOF
modprobe nvme-tcp
for a in 10.10.0.11 10.10.0.12; do
	nvme connect -t tcp -a \$a -s 4420 -n nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha \
	    --ctrl-loss-tmo=-1 --reconnect-delay=1
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
kill -9 "$(cat "$LAB/ctl-a/qemu.pid")"

log "ctl-b: import and take over"
# Given a whole disk, zpool create writes a GPT and puts the labels in
# partition 1.  ctl-b read the partition tables at boot, while the disks
# were blank, so it has no -part1 devices and zpool import answered "no
# such pool available" although blkid -p on ctl-b did see the new GPT.
# Flushing buffers and a udev change event do not touch the kernel's
# partition table; --rereadpt does.  On real dual-ported drives this is
# needed once after the pool is created, not at every takeover.
rc=0
on ctl-b sudo sh -eux > "$OUT/takeover.txt" 2>&1 <<'EOF' || rc=$?
# /proc/uptime, not date: the guests' wall clocks get stepped by time
# sync early on, and one run reported a host pause shorter than the
# import it was waiting for.
now() { cut -d' ' -f1 /proc/uptime; }
t0=$(now)
# Record the device nodes before and after, so the log shows the cause.
ls /dev/disk/by-id | grep shared || :
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	blockdev --rereadpt "$d"
done
udevadm settle
ls /dev/disk/by-id | grep shared || :
t1=$(now)
zpool import -d /dev/disk/by-id -f tankA
t2=$(now)
udevadm settle
for i in $(seq 30); do [ -e /dev/zvol/tankA/vol1 ] && break; sleep 1; done
sh /tmp/nvmet.sh ns /dev/zvol/tankA/vol1
sh /tmp/nvmet.sh ana 2 optimized
t3=$(now)
awk -v a="$t0" -v b="$t1" -v c="$t2" -v d="$t3" 'BEGIN {
    printf "takeover %.2f s: rescan %.2f s, import %.2f s, export %.2f s\n",
        d - a, b - a, c - b, d - c }'
EOF
cat "$OUT/takeover.txt"
# The import's own account of where the time went.
on ctl-b sudo cat /proc/spl/kstat/zfs/dbgmsg > "$OUT/ctl-b-dbgmsg.txt" || :
grep -E 'mmp|activity|import|spa_load' "$OUT/ctl-b-dbgmsg.txt" | head -40 || :
if [ $rc -ne 0 ]; then
	echo "takeover failed ($rc)" >&2
	kill "$writer" 2>/dev/null || :
	exit 1
fi

# Let the writer run on the new path, then stop it.  A writer whose I/O
# is still queued sits in the kernel and ignores the signal, so do not
# wait on it without a bound; drop the ssh instead.
sleep 20
on host "sudo pkill -f 'blocks.py write'" || :
sleep 3
kill "$writer" 2>/dev/null || :
on host sudo nvme list-subsys > "$OUT/subsys-after.txt"

last=$(tail -n 1 "$OUT/writer.log" | cut -d' ' -f1)
gap=$(awk 'NR > 1 { d = $2 - p; if (d > m) { m = d; at = $1 } } { p = $2 }
    END { printf "%.3f s before index %d", m, at }' "$OUT/writer.log")
log "writer: last acknowledged index $last, longest pause $gap"

log "host: verify every acknowledged block"
on host sudo python3 /tmp/blocks.py verify "$DEV" "$last" | tee "$OUT/verify.txt"

{
	echo "### failover, MMP interval ${MMP_INTERVAL} ms, fail intervals ${MMP_FAIL}"
	echo
	echo "- kernel: $(on host uname -r)"
	echo "- $(grep -m1 'mmp: settings' "$OUT/ctl-b-dbgmsg.txt" | sed 's/^[0-9]* *//')"
	echo "- writes before power loss: $before"
	echo "- $(grep '^takeover' "$OUT/takeover.txt")"
	echo "- longest host I/O pause: $gap"
	echo "- $(cat "$OUT/verify.txt")"
} | tee "$OUT/summary.md"
grep -q ', 0 bad' "$OUT/verify.txt"
