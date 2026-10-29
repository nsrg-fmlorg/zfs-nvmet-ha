#!/bin/sh
# Boot the AlmaLinux installer under qemu with two NVMe drives that carry
# an md RAID1 with LVM on it, as a shared drive left by the other node
# would, and record what the installer does with them.
#
#   INSTALLER_CASE=base         nothing done
#   INSTALLER_CASE=auto-all     /etc/mdadm.conf in the installer's root says
#                               AUTO -all (the file is put in /updates in
#                               the initrd, which dracut copies over the
#                               root before switching to it)
#   INSTALLER_CASE=vfio-ids     vfio-pci.ids= with the shared drives' PCI
#                               ID; the boot disk is virtio, so its ID differs
#   INSTALLER_CASE=override     all three drives have the same PCI ID; a
#                               pre-udev hook in the initrd sets
#                               driver_override on the shared drives' slots
#   INSTALLER_CASE=pre-teardown %pre deactivates LVM, stops md and unbinds
#                               the shared drives by slot
#
# The kickstart records /proc/mdstat, lsblk and dmsetup in %pre and again
# in %pre-install, after the installer has scanned the disks, then powers
# off.  The shared images' checksums before and after tell whether
# anything was written to them.
set -eu

CASE=${INSTALLER_CASE:-base}
HERE=$(cd "$(dirname "$0")" && pwd)
W=${W:-$(pwd)/work/installer}
OS=${OS_URL:-https://repo.almalinux.org/almalinux/10/BaseOS/x86_64/os}
# Shared drives sit in fixed slots so the hook and %pre can name them.
S0=0000:00:05.0 S1=0000:00:06.0
mkdir -p "$W"
cd "$W"

[ -f vmlinuz ] || curl -fsSL -o vmlinuz "$OS/images/pxeboot/vmlinuz"
[ -f initrd.img ] || curl -fsSL -o initrd.img "$OS/images/pxeboot/initrd.img"

# The other node's array: md RAID1 over both shared drives, a VG on it.
rm -f shared0.raw shared1.raw boot.raw
truncate -s 1G shared0.raw shared1.raw
truncate -s 12G boot.raw
l0=$(sudo losetup -f --show shared0.raw)
l1=$(sudo losetup -f --show shared1.raw)
sudo mdadm --create /dev/md/labshared --run --level=1 --raid-devices=2 \
    --metadata=1.2 --homehost=ctl-other --assume-clean "$l0" "$l1"
sudo pvcreate -q /dev/md/labshared
sudo vgcreate -q vgshared /dev/md/labshared
sudo lvcreate -q -L 200M -n data vgshared
sudo vgchange -q -an vgshared
# What the other node left, to compare with what the guest reads.
sudo mdadm --examine "$l0" > examine-runner.txt 2>&1 || :
sudo dd if="$l0" bs=4096 skip=1 count=1 status=none | od -A d -t x1 | head -n 16 > sb-runner.txt
sudo mdadm --stop /dev/md/labshared
sudo losetup -d "$l0" "$l1"
sha256sum shared0.raw shared1.raw > sum-before.txt

# The kickstart and updates come over HTTP from the runner (10.0.2.2 from
# the guest); only the override case adds to the initrd, for its hook.
rm -rf srv extra && mkdir -p srv extra
sed -e "s/@S0@/$S0/g" -e "s/@S1@/$S1/g" -e "s/@CASE@/$CASE/g" "$HERE/ks.cfg" > srv/ks.cfg
args="inst.repo=$OS inst.ks=http://10.0.2.2:8000/ks.cfg inst.text console=ttyS0"
boot="-device nvme,serial=boot,drive=boot,addr=0x4"
cp initrd.img initrd.case
case $CASE in
base|pre-teardown) ;;
auto-all)
	mkdir -p upd/etc
	printf 'HOMEHOST <ignore>\nAUTO -all\n' > upd/etc/mdadm.conf
	(cd upd && find . -mindepth 1 | cpio -o -H newc -R 0:0 --quiet | gzip) > srv/updates.img
	rm -rf upd
	args="$args inst.updates=http://10.0.2.2:8000/updates.img";;
vfio-ids)
	# qemu's NVMe controller is 1b36:0010.
	args="$args vfio-pci.ids=1b36:0010 rd.driver.pre=vfio-pci"
	boot="-device virtio-blk-pci,serial=boot,drive=boot,addr=0x4";;
override)
	# Where the hook is read from has moved between dracut versions.
	for d in usr/lib/dracut/hooks/pre-udev var/lib/dracut/hooks/pre-udev; do
		mkdir -p "extra/$d"
		printf 'for b in %s %s; do echo none > /sys/bus/pci/devices/$b/driver_override; done\n' \
		    "$S0" "$S1" > "extra/$d/00-shared-override.sh"
	done
	# No entry for the root directory itself, and owned by root: the
	# archive is laid over the initrd's own.
	(cd extra && find . -mindepth 1 | cpio -o -H newc -R 0:0 --quiet | gzip) > extra.cpio.gz
	cat initrd.img extra.cpio.gz > initrd.case;;
*)	echo "unknown INSTALLER_CASE $CASE" >&2; exit 2;;
esac
(cd srv && exec python3 -m http.server 8000 > ../http.log 2>&1) &
http=$!
trap 'kill $http 2>/dev/null || :' EXIT

rm -f console.log
# shellcheck disable=SC2086
timeout 2400 qemu-system-x86_64 -machine q35,accel=kvm -cpu host -smp 2 -m 4096 \
    -display none -monitor none -serial file:console.log -no-reboot \
    -kernel vmlinuz -initrd initrd.case -append "$args" \
    -netdev user,id=n -device virtio-net-pci,netdev=n,addr=0x3 \
    -drive file=boot.raw,format=raw,if=none,id=boot $boot \
    -drive file=shared0.raw,format=raw,if=none,id=s0 -device nvme,serial=shared0,drive=s0,addr=0x5 \
    -drive file=shared1.raw,format=raw,if=none,id=s1 -device nvme,serial=shared1,drive=s1,addr=0x6 \
    || echo "qemu exited $?"
sha256sum shared0.raw shared1.raw > sum-after.txt

# Sections the kickstart wrote between "=== <name>" and "=== end <name>".
# The installer's screen writes escape sequences around the records.
tr -d '\r' < console.log | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\x1b(B//g' > clean.log
sec() { awk -v n="$1" '$0 ~ "=== end " n "$" { p = 0 } p { print } $0 ~ "=== " n "$" { p = 1 }' clean.log; }
for s in pre pre-after-teardown pre-install; do sec "$s" > "$s.txt"; done
md() { grep -c '^md' "$1" 2>/dev/null || :; }
lv() { grep -c 'vgshared' "$1" 2>/dev/null || :; }
seen() { grep -c 'shared[01]' "$1" 2>/dev/null || :; }
{
	echo "### installer, case $CASE"
	echo
	echo "| point | md arrays | vgshared dm | shared drives in lsblk |"
	echo "|---|---|---|---|"
	for s in pre pre-after-teardown pre-install; do
		[ -s "$s.txt" ] && echo "| $s | $(md $s.txt) | $(lv $s.txt) | $(seen $s.txt) |"
	done
	echo
	if cmp -s sum-before.txt sum-after.txt; then
		echo "- shared drives unchanged (sha256)"
	else
		echo "- **shared drives were written to**"
	fi
	grep -q '=== pre-install$' clean.log || echo "- the installer never reached %pre-install"
} | tee summary.md
# Without the %pre record nothing was measured.
grep -q '=== pre$' clean.log || { echo "no %pre record; see console.log" >&2; tr -d '\r' < console.log | tail -n 40 >&2; exit 1; }
