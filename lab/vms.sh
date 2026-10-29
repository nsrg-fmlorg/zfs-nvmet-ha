#!/bin/sh
# Boot the three lab VMs on a Linux host with KVM:
#   ctl-a, ctl-b  storage controllers; both see the same two raw disks,
#                 standing in for dual-ported NVMe drives
#   host          the NVMe-oF initiator
# All three share an L2 segment (10.10.0.0/24) over a qemu multicast socket.
#
# usage: vms.sh up | down
#
# DISTRO picks the guests' distribution: ubuntu (24.04, the default),
# debian (12) or alma (AlmaLinux 9, for the RHEL family).  Every guest
# gets a user "ubuntu" whatever the distribution, so the scenarios log in
# the same way.
set -eu

LAB=${LAB:-$(pwd)/work}
DISTRO=${DISTRO:-ubuntu}
case $DISTRO in
ubuntu)	img=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img;;
# generic, not genericcloud: the cloud kernel leaves out nvmet.
debian)	img=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2;;
alma)	img=https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2;;
*)	echo "unknown DISTRO $DISTRO" >&2; exit 2;;
esac
IMG_URL=${IMG_URL:-$img}
BASE=$LAB/base.img
MCAST=230.0.0.1:12345

mkdir -p "$LAB"

# Packages per distribution.  ZFS is in Ubuntu's main archive, in
# Debian's contrib as DKMS, and for the RHEL family in OpenZFS's own
# kABI-tracking kmod repository.
setup_script() {
	ha=$1
	# Mirrors hand out a broken repomd.xml or index now and then; retry.
	echo 'r() { for i in 1 2 3 4 5; do "$@" && return; sleep 20; done; return 1; }'
	case $DISTRO in
	ubuntu)
		echo "r apt-get update -q"
		echo "r env DEBIAN_FRONTEND=noninteractive apt-get install -yq zfsutils-linux nvme-cli python3 linux-modules-extra-\$(uname -r)"
		[ -z "$ha" ] || echo "r env DEBIAN_FRONTEND=noninteractive apt-get install -yq pacemaker corosync resource-agents-base resource-agents-extra libxml2-utils git"
		;;
	debian)
		echo "sed -i 's/^Components: main\$/Components: main contrib/' /etc/apt/sources.list.d/debian.sources"
		echo "r apt-get update -q"
		echo "r env DEBIAN_FRONTEND=noninteractive apt-get install -yq linux-headers-\$(uname -r) zfs-dkms zfsutils-linux nvme-cli python3"
		[ -z "$ha" ] || echo "r env DEBIAN_FRONTEND=noninteractive apt-get install -yq pacemaker corosync resource-agents libxml2-utils git"
		;;
	alma)
		echo "r dnf install -yq https://zfsonlinux.org/epel/zfs-release-2-3.el9.noarch.rpm"
		echo "dnf config-manager --disable zfs"
		echo "dnf config-manager --enable zfs-kmod"
		echo "dnf install -yq kernel-modules-extra-\$(uname -r) || :"
		echo "r dnf install -yq zfs nvme-cli python3"
		[ -z "$ha" ] || echo "dnf config-manager --set-enabled highavailability"
		[ -z "$ha" ] || echo "r dnf install -yq pacemaker corosync resource-agents libxml2 git"
		;;
	esac
	echo "modprobe zfs"
}

vm_seed() {
	name=$1 n=$2 ha=${3:-}
	d=$LAB/$name
	mkdir -p "$d"
	setup_script "$ha" > "$d/setup.sh"
	cat > "$d/user-data" <<EOF
#cloud-config
hostname: $name
users:
  - default
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$LAB/id_ed25519.pub")
write_files:
  - path: /var/lib/cloud/lab-setup.sh
    encoding: b64
    content: $(base64 < "$d/setup.sh" | tr -d '\n')
runcmd:
  # lab-ready only when every package went in: a scenario started on a
  # guest whose install failed fails later, on whatever it lacks.
  - sh -eux /var/lib/cloud/lab-setup.sh > /var/log/lab-setup.log 2>&1 && zgenhostid -f 0x0000a00$n && touch /var/lib/cloud/lab-ready
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
		# And one disk of the controller's own, not shared, for a SLOG.
		[ -f "$d/local.raw" ] || truncate -s 1G "$d/local.raw"
		disks="$disks -drive file=$d/local.raw,format=raw,if=none,id=loc,cache=none,aio=native"
		disks="$disks -device virtio-blk-pci,drive=loc,serial=local"
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
	# (ocf-shellfuncs, ZFS); the host needs neither.
	vm_seed ctl-a 1 ha; vm_seed ctl-b 2 ha; vm_seed host 3
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
