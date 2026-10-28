#!/bin/sh
# SPDK's NVMe-oF target against the kernel's, on one VM, over NVMe/TCP on
# 127.0.0.1 so that the qemu multicast network between the VMs bounds
# nothing.  On ctl-a:
#
#   k-raw   kernel nvmet-tcp :4420, backed by null_blk /dev/nullb0
#   k-zvol  kernel nvmet-tcp :4420, backed by a zvol
#   s-null  SPDK nvmf_tgt :4421, backed by SPDK's own bdev_null
#   s-raw   SPDK nvmf_tgt :4421, bdev_uring on /dev/nullb0
#   s-zvol  SPDK nvmf_tgt :4421, bdev_uring on the same zvol
#
# The zvol lives on a mirror of two memory-backed null_blk devices, as in
# lab/perf.sh.  nvmf_tgt is pinned to one core (-m 0x2, core 1) and polls
# it at 100 %; the kernel host, fio and the kernel target share the rest.
# The VM has 2 cores, so SPDK runs with half the machine to itself.
set -eu

LAB=${LAB:-$(pwd)/work}
OUT=${OUT:-$LAB/out}
mkdir -p "$OUT"
echo "spdk-vs-kernel tcp" > "$OUT/config.txt"

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

n=0
until on ctl-a test -f /var/lib/cloud/lab-ready 2>/dev/null; do
	n=$((n + 1)); [ $n -lt 120 ] || { echo "ctl-a never became ready" >&2; exit 1; }
	sleep 10
done
put ctl-a "$LAB/spdk.tar.gz" spdk.tar.gz

on ctl-a sudo sh -eux > "$OUT/spdk-setup.txt" 2>&1 <<'EOF' || { cat "$OUT/spdk-setup.txt"; exit 1; }
apt-get install -yq fio > /dev/null
nproc; free -m; zfs version
mkdir -p /opt/spdk && tar -xzf /home/ubuntu/spdk.tar.gz -C /opt/spdk
# Keep the ARC from crowding out the hugepages and null_blk memory.
echo 536870912 > /sys/module/zfs/parameters/zfs_arc_max

modprobe null_blk nr_devices=0
mkcfg() {
	d=/sys/kernel/config/nullb/$1
	mkdir $d
	echo 4096 > $d/blocksize
	echo 2 > $d/queue_mode
	echo $2 > $d/memory_backed
	echo $3 > $d/size
	echo 1 > $d/power
}
mkcfg nullb0 0 4096
mkcfg nullb1 1 768
mkcfg nullb2 1 768
udevadm settle
zpool create -f -O compression=off perf mirror /dev/nullb1 /dev/nullb2
zfs create -V 128M -o volblocksize=16k perf/vol
udevadm settle
for i in $(seq 30); do [ -e /dev/zvol/perf/vol ] && break; sleep 1; done

# Kernel target, TCP on 127.0.0.1:4420.
modprobe nvmet; modprobe nvmet-tcp; modprobe nvme-tcp
C=/sys/kernel/config/nvmet
mkdir $C/ports/1
echo tcp > $C/ports/1/addr_trtype
echo ipv4 > $C/ports/1/addr_adrfam
echo 127.0.0.1 > $C/ports/1/addr_traddr
echo 4420 > $C/ports/1/addr_trsvcid
mk() {
	mkdir $C/subsystems/$1
	echo 1 > $C/subsystems/$1/attr_allow_any_host
	mkdir $C/subsystems/$1/namespaces/1
	echo $2 > $C/subsystems/$1/namespaces/1/device_path
	echo 1 > $C/subsystems/$1/namespaces/1/enable
	ln -s $C/subsystems/$1 $C/ports/1/subsystems/$1
}
# SPDK rejects NQNs that are not of the nqn.yyyy-mm.reverse.domain:name
# form (lib/nvmf/subsystem.c); the kernel takes anything.  Both get the
# full form so that the names compare the same way.
P=nqn.2026-10.org.fml.nsrg:
mk ${P}k-raw /dev/nullb0
mk ${P}k-zvol /dev/zvol/perf/vol

# SPDK target, TCP on 127.0.0.1:4421, one core, its RPC socket in /run.
echo 512 > /proc/sys/vm/nr_hugepages
grep -i hugepages_total /proc/meminfo
LD_LIBRARY_PATH=/opt/spdk/lib nohup /opt/spdk/build/bin/nvmf_tgt -m 0x2 -s 512 -r /run/spdk.sock \
    > /run/nvmf_tgt.log 2>&1 &
for i in $(seq 60); do [ -S /run/spdk.sock ] && break; sleep 1; done
rpc() { python3 /opt/spdk/scripts/rpc.py -s /run/spdk.sock "$@"; }
rpc framework_wait_init || :
rpc nvmf_create_transport -t TCP
rpc bdev_null_create snull 1024 4096
rpc bdev_uring_create /dev/nullb0 sraw 4096
rpc bdev_uring_create /dev/zvol/perf/vol szvol 4096
for s in s-null:snull s-raw:sraw s-zvol:szvol; do
	nqn=$P${s%%:*} bdev=${s#*:}
	rpc nvmf_create_subsystem -a -s SPDK$(echo ${s%%:*} | tr -d -) $nqn
	rpc nvmf_subsystem_add_ns $nqn $bdev
	rpc nvmf_subsystem_add_listener $nqn -t tcp -f ipv4 -a 127.0.0.1 -s 4421
done

# The kernel host connects to all five.
for s in k-raw k-zvol; do nvme connect -t tcp -a 127.0.0.1 -s 4420 -n $P$s; done
for s in s-null s-raw s-zvol; do nvme connect -t tcp -a 127.0.0.1 -s 4421 -n $P$s; done
udevadm settle
sleep 2
for d in /sys/class/nvme/nvme*; do echo "${d##*/} $(cat $d/subsysnqn)"; done
EOF
grep -v '^+' "$OUT/spdk-setup.txt" | tail -n 12

dev_of() {
	# The trailing true: a last non-matching test would leave the loop with
	# status 1, and set -e would stop the script on it.
	on ctl-a "for d in /sys/class/nvme/nvme*; do [ \"\$(cat \$d/subsysnqn)\" = nqn.2026-10.org.fml.nsrg:$1 ] && echo /dev/\${d##*/}n1; done; true"
}

# Same jobs as lab/perf.sh, with whole-VM CPU from /proc/stat around each.
run() {
	path=$1 job=$2 dev=$3; shift 3
	on ctl-a "head -n 1 /proc/stat" > "$OUT/stat-$path-$job.before"
	on ctl-a sudo fio --name="$path-$job" --filename="$dev" --direct=1 \
	    --ioengine=io_uring --size=128M --time_based --ramp_time=5 --runtime=20 \
	    --group_reporting --output-format=json "$@" > "$OUT/fio-$path-$job.json"
	on ctl-a "head -n 1 /proc/stat" > "$OUT/stat-$path-$job.after"
}

for path in k-raw k-zvol s-null s-raw s-zvol; do
	dev=$(dev_of $path)
	[ -n "$dev" ] || { echo "no device for $path" >&2; exit 1; }
	echo "== $path: $dev"
	run "$path" randread "$dev" --rw=randread --bs=4k --iodepth=32 --numjobs=2
	run "$path" randwrite "$dev" --rw=randwrite --bs=4k --iodepth=32 --numjobs=2
	run "$path" syncwrite "$dev" --rw=randwrite --bs=4k --iodepth=1 --numjobs=1 --fsync=1
	run "$path" seqread "$dev" --rw=read --bs=128k --iodepth=16 --numjobs=1
done
on ctl-a "sudo tail -n 20 /run/nvmf_tgt.log" > "$OUT/nvmf_tgt.log" || :
python3 "$(dirname "$0")/spdk-agg.py" "$OUT" | tee "$OUT/summary.md"
