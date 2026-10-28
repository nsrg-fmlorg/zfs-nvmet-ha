#!/bin/sh
# Boot the three lab VMs on a Linux host with KVM:
#   ctl-a, ctl-b  storage controllers; both see the same two raw disks,
#                 standing in for dual-ported NVMe drives
#   host          the NVMe-oF initiator
# All three share an L2 segment (10.10.0.0/24) over a qemu multicast socket.
#
# usage: vms.sh up | down
set -eu

LAB=${LAB:-$(pwd)/work}
IMG_URL=${IMG_URL:-https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img}
BASE=$LAB/base.img
MCAST=230.0.0.1:12345

mkdir -p "$LAB"

vm_seed() {
	name=$1 n=$2 extra=${3:-}
	d=$LAB/$name
	mkdir -p "$d"
	cat > "$d/user-data" <<EOF
#cloud-config
hostname: $name
ssh_authorized_keys:
  - $(cat "$LAB/id_ed25519.pub")
package_update: true
packages: [zfsutils-linux, nvme-cli, python3$extra]
runcmd:
  - apt-get install -y linux-modules-extra-\$(uname -r)
  - zgenhostid -f 0x0000a00$n
  - touch /var/lib/cloud/lab-ready
EOF
	cat > "$d/network-config" <<EOF
version: 2
ethernets:
  wan:
    match: {macaddress: "52:54:00:12:34:0$n"}
    dhcp4: true
  lab:
    match: {macaddress: "52:54:00:00:01:0$n"}
    addresses: [10.10.0.1$n/24]
EOF
	cloud-localds --network-config="$d/network-config" "$d/seed.img" "$d/user-data"
	qemu-img create -q -f qcow2 -F qcow2 -b "$BASE" "$d/root.qcow2" 10G
}

vm_start() {
	name=$1 n=$2 cpus=$3 mem=$4 shared=$5
	d=$LAB/$name
	disks=
	if [ "$shared" = yes ]; then
		# file.locking=off and share-rw=on let both controllers open the
		# same image, as both ports of a dual-ported drive would be.
		for i in 0 1; do
			disks="$disks -drive file=$LAB/shared$i.raw,format=raw,if=none,id=sh$i,cache=none,aio=native,file.locking=off"
			disks="$disks -device virtio-blk-pci,drive=sh$i,share-rw=on,serial=shared$i"
		done
	fi
	# Not -daemonize: that discards qemu's stderr, and a guest that never
	# prints to the console leaves nothing else to read.
	# shellcheck disable=SC2086
	nohup qemu-system-x86_64 -name "$name" -machine q35,accel=kvm -cpu host \
	    -smp "$cpus" -m "$mem" -display none \
	    -pidfile "$d/qemu.pid" -serial "file:$d/console.log" \
	    -drive file="$d/root.qcow2",if=none,id=root \
	    -device virtio-blk-pci,drive=root,bootindex=0 \
	    -drive file="$d/seed.img",if=virtio,format=raw \
	    -netdev user,id=wan,hostfwd=tcp:127.0.0.1:222$n-:22 \
	    -device virtio-net-pci,netdev=wan,mac=52:54:00:12:34:0$n \
	    -netdev socket,id=lab,mcast=$MCAST \
	    -device virtio-net-pci,netdev=lab,mac=52:54:00:00:01:0$n \
	    $disks < /dev/null > "$d/qemu.log" 2>&1 &
}

# A qemu that rejects its arguments exits within a second or two.
vm_alive() {
	sleep 5
	for v in "$@"; do
		if ! kill -0 "$(cat "$LAB/$v/qemu.pid" 2>/dev/null)" 2>/dev/null; then
			echo "$v: qemu is not running" >&2
			cat "$LAB/$v/qemu.log" >&2
			return 1
		fi
	done
}

case ${1:-} in
up)
	[ -f "$BASE" ] || curl -fsSL -o "$BASE" "$IMG_URL"
	[ -f "$LAB/id_ed25519" ] || ssh-keygen -q -t ed25519 -N '' -f "$LAB/id_ed25519"
	for i in 0 1; do
		[ -f "$LAB/shared$i.raw" ] || truncate -s 4G "$LAB/shared$i.raw"
	done
	# The controllers also get the cluster stack and the stock agents
	# (ocf-shellfuncs, ZFS, Delay); the host needs neither.
	ha=', pacemaker, corosync, resource-agents-base, resource-agents-extra, libxml2-utils, git'
	vm_seed ctl-a 1 "$ha"; vm_seed ctl-b 2 "$ha"; vm_seed host 3
	# CTL_MEM: SPDK's hugepages need more than the default 3G on ctl-a.
	vm_start ctl-a 1 2 "${CTL_MEM:-3G}" yes
	vm_start ctl-b 2 2 3G yes
	vm_start host 3 1 1536M no
	vm_alive ctl-a ctl-b host
	;;
down)
	for v in ctl-a ctl-b host; do
		p=$LAB/$v/qemu.pid
		[ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null || :
	done
	;;
*)
	echo "usage: $0 up | down" >&2; exit 2;;
esac
