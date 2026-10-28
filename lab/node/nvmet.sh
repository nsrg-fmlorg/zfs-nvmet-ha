#!/bin/sh
# Configure the kernel NVMe-oF target (nvmet) through configfs on a
# controller node.  Both controllers export the same subsystem NQN, the
# same serial and the same namespace UUID/NGUID, so the host's native
# multipath treats them as two paths to one namespace.
#
#   nvmet.sh port <portid> <traddr> <cntlid_min> <cntlid_max> <ana_state>
#   nvmet.sh ns <device>
#   nvmet.sh ana <portid> <ana_state>
#
# The cntlid ranges must not overlap between the two controllers: the
# host keys controllers by (subsystem NQN, cntlid), and two controllers
# both answering cntlid 1 look like one controller to it.
set -eu

NQN=${NQN:-nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha}
SERIAL=${SERIAL:-5a46534e564d4554}
NSUUID=${NSUUID:-6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001}
NSNGUID=${NSNGUID:-6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001}
CFG=/sys/kernel/config/nvmet
S=$CFG/subsystems/$NQN

subsys() {
	modprobe nvmet
	modprobe nvmet-tcp
	[ -d "$S" ] && return 0
	mkdir "$S"
	echo 1 > "$S/attr_allow_any_host"
	echo "$SERIAL" > "$S/attr_serial"
	echo "$1" > "$S/attr_cntlid_min"
	echo "$2" > "$S/attr_cntlid_max"
}

case $1 in
port)
	portid=$2 traddr=$3
	subsys "$4" "$5"
	P=$CFG/ports/$portid
	mkdir -p "$P"
	echo tcp > "$P/addr_trtype"
	echo ipv4 > "$P/addr_adrfam"
	echo "$traddr" > "$P/addr_traddr"
	echo 4420 > "$P/addr_trsvcid"
	echo "$6" > "$P/ana_groups/1/ana_state"
	ln -sf "$S" "$P/subsystems/$NQN"
	;;
ns)
	N=$S/namespaces/1
	mkdir -p "$N"
	echo "$2" > "$N/device_path"
	echo "$NSUUID" > "$N/device_uuid"
	echo "$NSNGUID" > "$N/device_nguid"
	echo 1 > "$N/ana_grpid"
	echo 1 > "$N/enable"
	;;
ana)
	echo "$3" > "$CFG/ports/$2/ana_groups/1/ana_state"
	;;
*)
	echo "usage: $0 port|ns|ana ..." >&2; exit 2;;
esac
