#!/bin/sh
# Where does the time go on the I/O path, without the network?  On ctl-a,
# with null_blk standing in for the drives, run the same fio jobs against
#
#   raw      /dev/nullb0 directly
#   zvol     a zvol on a pool built on two memory-backed null_blk devices
#   loop-raw nvmet over the nvme-loop transport, backed by /dev/nullb0
#   loop-zvol the same, backed by the zvol
#
# The lab's VMs talk over a qemu multicast socket, which would bound any
# measurement taken across it, so nothing here crosses it.  The numbers
# are for comparing paths with each other on one VM, not absolute.
set -eu

LAB=${LAB:-$(pwd)/work}
OUT=${OUT:-$LAB/out}
# What to take out of ZFS's write path: PERF_LAYOUT=mirror|single,
# PERF_CKSUM=on|off (off only to measure what the checksums cost).
PERF_LAYOUT=${PERF_LAYOUT:-mirror}
PERF_CKSUM=${PERF_CKSUM:-on}
# Size of each memory-backed null_blk under the pool, MiB.  At 768 the
# pool held four 128 MiB zvols with little room left, and txgs closed
# after a few milliseconds; a larger pool tells whether that was the
# lab's doing.
PERF_NULLB_MB=${PERF_NULLB_MB:-768}
export PERF_LAYOUT PERF_CKSUM
mkdir -p "$OUT"
echo "$PERF_LAYOUT $PERF_CKSUM" > "$OUT/config.txt"

port() { case $1 in ctl-a) echo 2221;; ctl-b) echo 2222;; host) echo 2223;; esac; }
on() {
	v=$1; shift
	ssh -q -i "$LAB/id_ed25519" -p "$(port "$v")" \
	    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
	    -o ConnectTimeout=5 ubuntu@127.0.0.1 "$@"
}

n=0
until on ctl-a test -f /var/lib/cloud/lab-ready 2>/dev/null; do
	n=$((n + 1)); [ $n -lt 120 ] || { echo "ctl-a never became ready" >&2; exit 1; }
	sleep 10
done

echo "LAYOUT=$PERF_LAYOUT CKSUM=$PERF_CKSUM NULLB_MB=$PERF_NULLB_MB" | on ctl-a sudo tee /run/perf.cfg > /dev/null
on ctl-a sudo sh -eux > "$OUT/perf-setup.txt" 2>&1 <<'EOF' || { cat "$OUT/perf-setup.txt"; exit 1; }
# perf, to see where the kernel spends its time on the slow paths.
apt-get install -yq fio linux-tools-common linux-tools-$(uname -r) > /dev/null
nproc; free -m; zfs version
# nullb0: completes without storing, the floor of the block layer.
# nullb1, nullb2: memory-backed, 768 MiB each, so a pool can live on them.
modprobe null_blk nr_devices=0
mkcfg() {
	d=/sys/kernel/config/nullb/$1
	mkdir $d
	echo 4096 > $d/blocksize
	echo 2 > $d/queue_mode            # blk-mq
	echo $2 > $d/memory_backed
	echo $3 > $d/size                 # MiB
	echo 1 > $d/power
}
mkcfg nullb0 0 4096
. /run/perf.cfg
# The pool's disks live in RAM; keep the ARC from taking what they need.
echo $((768 * 1024 * 1024)) > /sys/module/zfs/parameters/zfs_arc_max
mkcfg nullb1 1 $NULLB_MB
mkcfg nullb2 1 $NULLB_MB
udevadm settle
. /run/perf.cfg
if [ "$LAYOUT" = single ]; then
	zpool create -f -O compression=off -O checksum=$CKSUM perf /dev/nullb1
else
	zpool create -f -O compression=off -O checksum=$CKSUM perf mirror /dev/nullb1 /dev/nullb2
fi
zfs create -V 128M -o volblocksize=16k perf/vol
# 4 KiB blocks, to match the 4 KiB writes and avoid read-modify-write of
# a 16 KiB block on each one.
zfs create -V 128M -o volblocksize=4k perf/vol4k
# The same through the blk-mq interface.  zvol_os.c reads zvol_use_blk_mq
# when a zvol is loaded, so the parameter has to be set before creating it.
echo 1 > /sys/module/zfs/parameters/zvol_use_blk_mq
zfs create -V 128M -o volblocksize=4k perf/vol4kmq
# A file on a ZFS file system, to tell zvol costs from ZFS costs.
zfs create -o recordsize=16k -o mountpoint=/perf/fs perf/fs
udevadm settle
for v in vol vol4k vol4kmq; do
	for i in $(seq 30); do [ -e /dev/zvol/perf/$v ] && break; sleep 1; done
done
cat /sys/module/zfs/parameters/zfs_dirty_data_max
# A zvol nobody has written must read back as zeros: blocks never
# written are holes, and ZFS returns zeros for them rather than whatever
# the disks held.
zfs create -V 64M perf/fresh
udevadm settle
for i in $(seq 30); do [ -e /dev/zvol/perf/fresh ] && break; sleep 1; done
if cmp -s -n $((64 * 1024 * 1024)) /dev/zvol/perf/fresh /dev/zero; then echo "fresh zvol: all zeros"; else echo "fresh zvol: NOT all zeros"; fi
zfs destroy perf/fresh

modprobe nvmet; modprobe nvme-loop; modprobe nvme-fabrics
C=/sys/kernel/config/nvmet
mkdir $C/ports/9
echo loop > $C/ports/9/addr_trtype
for s in raw zvol zvol4k zvol4k-mq; do
	mkdir $C/subsystems/perf-$s
	echo 1 > $C/subsystems/perf-$s/attr_allow_any_host
	mkdir $C/subsystems/perf-$s/namespaces/1
done
echo /dev/nullb0 > $C/subsystems/perf-raw/namespaces/1/device_path
echo /dev/zvol/perf/vol > $C/subsystems/perf-zvol/namespaces/1/device_path
echo /dev/zvol/perf/vol4k > $C/subsystems/perf-zvol4k/namespaces/1/device_path
echo /dev/zvol/perf/vol4kmq > $C/subsystems/perf-zvol4k-mq/namespaces/1/device_path
for s in raw zvol zvol4k zvol4k-mq; do
	echo 1 > $C/subsystems/perf-$s/namespaces/1/enable
	ln -s $C/subsystems/perf-$s $C/ports/9/subsystems/perf-$s
	nvme connect -t loop -n perf-$s
done
udevadm settle
sleep 2
for d in /sys/class/nvme/nvme*; do echo "${d##*/} $(cat $d/subsysnqn)"; done

# The same two backends behind another kernel target: LIO, with the
# iblock backstore and the tcm_loop fabric, which shows them as local
# SCSI disks.  If writes to the zvol are slow through LIO too, the cost
# is in how ZFS takes these writes; if not, it is particular to nvmet.
# LUN 0 is the null_blk, LUN 1 the zvol (drivers/target/loopback/
# tcm_loop.c and target_core_iblock.c, v6.8, for the configfs names).
modprobe target_core_mod; modprobe target_core_iblock; modprobe tcm_loop; modprobe sd_mod
T=/sys/kernel/config/target
mkdir -p $T/core/iblock_0/raw $T/core/iblock_1/zv
echo udev_path=/dev/nullb0 > $T/core/iblock_0/raw/control
echo 1 > $T/core/iblock_0/raw/enable
echo udev_path=/dev/zvol/perf/vol > $T/core/iblock_1/zv/control
echo 1 > $T/core/iblock_1/zv/enable
# The nexus first: it creates the SCSI host, and linking a LUN adds its
# disk to that host.  LUNs linked before the nexus produced no disks.
W=$T/loopback/naa.5001405000000001/tpgt_1
mkdir -p $W
echo naa.5001405000000002 > $W/nexus
mkdir -p $W/lun/lun_0 $W/lun/lun_1
ln -s $T/core/iblock_0/raw $W/lun/lun_0/raw
ln -s $T/core/iblock_1/zv $W/lun/lun_1/zv
udevadm settle
sleep 2
for b in /sys/block/sd*; do echo "${b##*/} $(cat $b/device/vendor) lun $(basename $(readlink -f $b/device) | cut -d: -f4)"; done; true
EOF
cat "$OUT/perf-setup.txt" | grep -v '^+' | tail -n 12

# The device for each path, resolved on ctl-a.
dev_of() {
	case $1 in
	raw) echo /dev/nullb0;;
	zvol) echo /dev/zvol/perf/vol;;
	zvol4k) echo /dev/zvol/perf/vol4k;;
	zvol4k-mq) echo /dev/zvol/perf/vol4kmq;;
	zfsfile) echo /perf/fs/file;;
	lio-raw|lio-zvol)
		# LIO-ORG disk with the LUN that backs this path
		[ $1 = lio-raw ] && lun=0 || lun=1
		on ctl-a "for b in /sys/block/sd*; do [ \"\$(cat \$b/device/vendor | tr -d ' ')\" = LIO-ORG ] && [ \"\$(basename \$(readlink -f \$b/device) | cut -d: -f4)\" = $lun ] && echo /dev/\${b##*/}; done; true";;
	loop-*)
		s=perf-${1#loop-}
		# The trailing true: a last non-matching test would leave the loop
		# with status 1, and set -e stopped the script on it.
		on ctl-a "for d in /sys/class/nvme/nvme*; do [ \"\$(cat \$d/subsysnqn)\" = $s ] && echo /dev/\${d##*/}n1; done; true";;
	esac
}

# Each job runs 20 s after a 5 s ramp over the same 160 MiB on every path.
# The zvols are 160 MiB: the pool is a 768 MiB mirror in a 3 GB VM, and
# three 512 MiB zvols ran it out of space at the second.
run() {
	path=$1 job=$2 dev=$3; shift 3
	# fio's own CPU figure leaves out the kernel threads ZFS writes with, so
	# take the whole VM's CPU from /proc/stat, ZFS's write-throttle counters,
	# its ZIL counters (does a write through nvmet commit the ZIL?), the
	# pool's write operations reaching the disks, and the txgs, before
	# and after.
	on ctl-a "head -n 1 /proc/stat; cat /proc/spl/kstat/zfs/dmu_tx /proc/spl/kstat/zfs/zil; sudo zpool iostat -Hp perf | awk '{print \"zpool_write_ops 4 \" \$5}'; tail -n 1 /proc/spl/kstat/zfs/perf/txgs | awk '{print \"txg_count 4 \" \$1}'" > "$OUT/stat-$path-$job.before"
	on ctl-a sudo fio --name="$path-$job" --filename="$dev" --direct=1 \
	    --ioengine=io_uring --size=128M --time_based --ramp_time=5 --runtime=20 \
	    --group_reporting --output-format=json "$@" > "$OUT/fio-$path-$job.json"
	on ctl-a "head -n 1 /proc/stat; cat /proc/spl/kstat/zfs/dmu_tx /proc/spl/kstat/zfs/zil; sudo zpool iostat -Hp perf | awk '{print \"zpool_write_ops 4 \" \$5}'; tail -n 1 /proc/spl/kstat/zfs/perf/txgs | awk '{print \"txg_count 4 \" \$1}'" > "$OUT/stat-$path-$job.after"
	# What the txgs held: a random-write run on a zvol went through a
	# hundred or more txgs a second instead of one per five seconds.
	on ctl-a "cat /proc/spl/kstat/zfs/perf/txgs" > "$OUT/txgs-$path-$job.txt" || :
}

for path in raw zvol zvol4k zvol4k-mq zfsfile loop-raw loop-zvol loop-zvol4k loop-zvol4k-mq lio-raw lio-zvol; do
	dev=$(dev_of $path)
	[ -n "$dev" ] || { echo "no device for $path" >&2; exit 1; }
	echo "== $path: $dev"
	run "$path" randread "$dev" --rw=randread --bs=4k --iodepth=32 --numjobs=2
	run "$path" randwrite "$dev" --rw=randwrite --bs=4k --iodepth=32 --numjobs=2
	# One synchronous write at a time, as a database's log would issue them.
	run "$path" syncwrite "$dev" --rw=randwrite --bs=4k --iodepth=1 --numjobs=1 --fsync=1
	run "$path" seqread "$dev" --rw=read --bs=128k --iodepth=16 --numjobs=1
done

# Where the CPU goes: 10 s of system-wide samples in the middle of a
# 4 KiB random write run, on the zvol directly and through nvmet.
for path in zvol loop-zvol; do
	dev=$(dev_of $path)
	on ctl-a "sudo fio --name=prof --filename=$dev --direct=1 --ioengine=io_uring --size=128M \
	    --time_based --runtime=25 --rw=randwrite --bs=4k --iodepth=32 --numjobs=2 > /dev/null 2>&1 &
	    sleep 8
	    sudo perf record -a -g -o /run/perf-$path.data -- sleep 10 > /dev/null 2>&1
	    wait
	    sudo perf report -i /run/perf-$path.data --stdio --no-children --sort sym 2>/dev/null \
	        | grep -E '^ +[0-9.]+%' | head -n 40" > "$OUT/profile-$path.txt" || :
done

python3 - "$OUT" <<'EOF' | tee "$OUT/summary.md"
import json, sys, os
out = sys.argv[1]
paths = ["raw", "zvol", "zvol4k", "zvol4k-mq", "zfsfile", "loop-raw", "loop-zvol", "loop-zvol4k", "loop-zvol4k-mq", "lio-raw", "lio-zvol"]
jobs = [("randread", "read", "kIOPS"), ("randwrite", "write", "kIOPS"),
        ("syncwrite", "write", "kIOPS"), ("seqread", "read", "MiB/s")]
print("### I/O path comparison on one VM (null_blk underneath), pool %s, checksum %s\n" % (os.environ.get("PERF_LAYOUT", "mirror"), os.environ.get("PERF_CKSUM", "on")))
def stat(p, j, when):
    lines = open(os.path.join(out, f"stat-{p}-{j}.{when}")).read().split("\n")
    cpu = [int(x) for x in lines[0].split()[1:]]
    kv = {}
    for l in lines[1:]:
        f = l.split()
        if len(f) == 3 and f[2].isdigit():
            kv[f[0]] = int(f[2])
    return cpu, kv
def busy_and_throttle(p, j):
    c0, k0 = stat(p, j, "before"); c1, k1 = stat(p, j, "after")
    d = [b - a for a, b in zip(c0, c1)]
    idle = d[3] + d[4]                      # idle + iowait
    busy = 100.0 * (sum(d) - idle) / sum(d)
    thr = {k: k1.get(k, 0) - k0.get(k, 0) for k in ("dmu_tx_dirty_delay", "dmu_tx_dirty_over_max", "dmu_tx_dirty_throttle")}
    return busy, thr
print("| path | " + " | ".join(f"{j} {u}" for j, _, u in jobs) + " | randwrite: VM busy % | randwrite: dirty delay / over max |")
print("|---|" + "---|" * (len(jobs) + 2))
for p in paths:
    cells = []
    cpu = ""
    for j, side, unit in jobs:
        f = os.path.join(out, f"fio-{p}-{j}.json")
        r = json.load(open(f))["jobs"][0]
        s = r[side]
        if unit == "kIOPS":
            cells.append(f"{s['iops'] / 1000:.1f}")
        elif unit == "MiB/s":
            cells.append(f"{s['bw'] / 1024:.0f}")
        else:
            cells.append(f"{s['clat_ns']['percentile']['50.000000'] / 1000:.0f}")
    busy, thr = busy_and_throttle(p, "randwrite")
    print(f"| {p} | " + " | ".join(cells) + f" | {busy:.0f} | {thr['dmu_tx_dirty_delay']} / {thr['dmu_tx_dirty_over_max']} |")
EOF
