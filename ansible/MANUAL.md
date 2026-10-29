# Building the two controllers by hand

The same procedure as `site.yml`, step for step: each `Step N` here is
the group of tasks under the same `# Step N.` comment in the playbook,
and `ci/check-steps.py` fails the build when the two lists of steps
differ.  CI also runs every `sh` block of this file, in order, on a
fresh lab, and then the same checks as after the playbook
(`.github/workflows/ansible.yml`, job `manual`).

Every block names where it runs:

- `ctl-a`, `ctl-b`: as root on that controller
- `both`: as root on each controller, ctl-a first
- `admin`: on a workstation that reaches both controllers and the host
  as `ssh ctl-a`, `ssh ctl-b` and `ssh host`, with sudo there, and has
  a checkout of this repository as its current directory

The values are the lab's (`lab/vms.sh`): the storage network is
10.10.0.0/24, the shared drives appear as
`/dev/disk/by-id/virtio-shared0` and `virtio-shared1`, and each is split
in two partitions standing in for the two namespaces of a dual-ported
drive.  Replace them with yours.  `README.md` explains what each value
means.

## Installing the OS without touching the shared drives

Before any of the steps: AlmaLinux's installer must not assemble md
arrays it finds on the shared drives.  An array the installer on one
controller assembles, and perhaps resyncs, writes to drives the other
controller may be using.

The installer assembles them itself, not through udev.  Anaconda turns
on blivet's `auto_dev_updates`
(`pyanaconda/modules/storage/initialization.py`), and with it blivet's
populator activates every complete array it finds, with explicit
members and UUID (`md_array.setup()` in
`blivet/populator/helpers/mdraid.py`).  So neither of the obvious knobs
stops it:

- `AUTO -all` in `/etc/mdadm.conf` only governs `mdadm`'s own automatic
  assembly, which blivet does not go through.
- kickstart's `ignoredisk` hides disks only after blivet has scanned,
  and activated, everything (`populate()` in
  `blivet/populator/populator.py`).

What keeps the drives out is not letting the installer's kernel bind
the nvme driver to them at all.  Boot the installer with

    vfio-pci.ids=<vendor>:<device> rd.driver.pre=vfio-pci

naming the shared drives' PCI vendor and device IDs (`lspci -nn` on the
controller lists them): vfio-pci takes those devices first, and the
installer sees only the boot drive.  This has been reported to work on
real hardware; it has not been run in the lab, whose shared disks are
virtio.  It cannot be used when the boot drive has the same vendor and
device ID as the shared drives, since it would hide the boot drive too.

`vfio-pci.ids` is not among the boot options the installer carries
into the installed system (`preserved_arguments` in Anaconda's
`data/anaconda.conf`), so the installed system binds nvme to every drive
as it should.  There, udev does run `mdadm --incremental` on drives with
an md superblock (mdadm's `64-md-raid-assembly.rules`), and that is what
step 4's `AUTO -all` stops.

## Settings

Each controller keeps its own values in one file that every later block
reads.

```sh admin
ssh ctl-a "sudo tee /etc/zfs-nvmet-ha.env > /dev/null" <<'EOF'
ADDR=10.10.0.11 NODEID=1 HOSTID=0x0000a001 CNTLID_MIN=1 CNTLID_MAX=999 PORT_ID=1
EOF
ssh ctl-b "sudo tee /etc/zfs-nvmet-ha.env > /dev/null" <<'EOF'
ADDR=10.10.0.12 NODEID=2 HOSTID=0x0000a002 CNTLID_MIN=1000 CNTLID_MAX=1999 PORT_ID=2
EOF
```

## Step 1. Repositories

OpenZFS's packages for EL10 come from its **testing** repository: the
`zfs-release` that defines the repositories for EL10 is published only
under `epel-testing/10/`, and the testing kmod repository carries the
2.4 series.  Measured: AlmaLinux 10.2, kernel 6.12.0-211.64.1.el10_2,
`kmod-zfs-2.4.4-1.el10`.  The `.repo` file marks `zfs-testing-kmod`
deprecated in favour of `zfs-latest-kmod`, which carries the same 2.4.4
kmod but was not the one run.  ZFS multihost's import delay on 2.4 was
not measured, and may differ from 2.2's.  This procedure uses the kABI-tracking kmod, which needs no
compiler on the node but only covers the kernels of the current EL
minor release, as the playbook does by default
(`zfs_ha_zfs_style: kmod`).  The `.repo` file defines `zfs`, `zfs-kmod`,
`zfs-testing` and `zfs-testing-kmod`; exactly one is enabled.

download.zfsonlinux.org resets https connections, so the rpm comes over
http and is installed only once its signature checks against OpenZFS's
key (fingerprint `7DC7 299D CF7C 7FD9 CD87 701B A599 FD5E 9DB8 4141`,
as OpenZFS's RHEL page lists it), which comes over https.

```sh both
rpm --import https://raw.githubusercontent.com/zfsonlinux/zfsonlinux.github.com/master/zfs-release/RPM-GPG-KEY-openzfs-key2
curl -fsSL -o /var/tmp/zfs-release.rpm http://download.zfsonlinux.org/epel-testing/10/zfs-release-3-1.el10.noarch.rpm
rpm -K /var/tmp/zfs-release.rpm | grep -q 'signatures OK'
dnf install -y /var/tmp/zfs-release.rpm
dnf config-manager --set-disabled zfs zfs-kmod zfs-testing zfs-testing-kmod
dnf config-manager --set-enabled zfs-testing-kmod
dnf config-manager --set-enabled highavailability
```

On EL9, install `https://zfsonlinux.org/epel/zfs-release-3-0.el9.noarch.rpm`
and enable `zfs-kmod` instead.  For DKMS, enable `zfs-testing` (or `zfs`)
instead of the kmod section, then `dnf install -y epel-release` and
`dnf install -y dkms kernel-devel-$(uname -r)`.

## Step 2. Packages

```sh both
dnf install -y zfs nvme-cli pacemaker corosync pcs resource-agents git patch
```

## Step 3. Hostid, and no pool import at boot

ZFS multihost tells the controllers apart by hostid, so each needs its
own.  Pools are imported by Pacemaker only: a controller that imported
them at boot would race the other one for them.

```sh both
. /etc/zfs-nvmet-ha.env
[ "0x$(hostid)" = "$HOSTID" ] || zgenhostid -f "$HOSTID"
systemctl disable zfs-import-cache.service zfs-import-scan.service
```

## Step 4. No automatic md assembly

In the installed system, mdadm's udev rule
(`64-md-raid-assembly.rules`) runs `mdadm --incremental` on every device
carrying an md superblock.  On a drive both
controllers see, an array the standby assembles, and perhaps resyncs,
writes under the active node.  `AUTO -all` stops automatic assembly;
`HOMEHOST <ignore>` is what the stock file carries.  The installer is a
different matter; see the first section.

```sh both
cat > /etc/mdadm.conf <<'EOF'
# Managed by ansible/site.yml; see MANUAL.md, step 4.
HOMEHOST <ignore>
AUTO -all
EOF
```

## Step 5. Kernel modules

```sh both
cat > /etc/modules-load.d/zfs-nvmet-ha.conf <<'EOF'
zfs
nvmet
nvmet-tcp
EOF
modprobe -a zfs nvmet nvmet-tcp
```

## Step 6. Resource agents

The nvmet agents with controller ID ranges and ANA groups are
`lab/patches/resource-agents-nvmet-ana-cntlid.diff` on top of
ClusterLabs/resource-agents 81e937fd.  AlmaLinux's resource-agents does
not ship the ZFS agent; it comes from the same checkout.

```sh admin
for n in ctl-a ctl-b; do
	ssh $n "sudo tee /usr/local/src/resource-agents.diff > /dev/null" < lab/patches/resource-agents-nvmet-ana-cntlid.diff
done
```

```sh both
d=/usr/local/src/resource-agents
[ -d $d/.git ] || git clone -q --filter=blob:none https://github.com/ClusterLabs/resource-agents.git $d
git -C $d checkout -q -f 81e937fdb694d39aafbb9ac8ca415b188bb0751b
git -C $d apply $d.diff
for a in nvmet-subsystem nvmet-namespace nvmet-port; do
	install -m 0755 $d/heartbeat/$a /usr/lib/ocf/resource.d/heartbeat/$a
done
[ -e /usr/lib/ocf/resource.d/heartbeat/ZFS ] || install -m 0755 $d/heartbeat/ZFS /usr/lib/ocf/resource.d/heartbeat/ZFS
```

## Step 7. Firewall

```sh both
if systemctl -q is-active firewalld; then
	firewall-cmd --permanent --add-service=high-availability
	firewall-cmd --permanent --add-port=4420/tcp
	firewall-cmd --reload
fi
```

## Step 8. Corosync and Pacemaker

Two nodes with `two_node`, and the cluster traffic encrypted with one
key made on ctl-a and copied to ctl-b.

```sh both
cat > /etc/corosync/corosync.conf <<'EOF'
totem {
	version: 2
	cluster_name: zfs-ha
	transport: knet
	crypto_cipher: aes256
	crypto_hash: sha256
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
```

```sh ctl-a
[ -e /etc/corosync/authkey ] || corosync-keygen -l
```

```sh admin
ssh ctl-a sudo cat /etc/corosync/authkey | ssh ctl-b "sudo sh -c 'cat > /etc/corosync/authkey; chmod 0400 /etc/corosync/authkey'"
```

```sh both
systemctl enable --now corosync pacemaker
```

```sh ctl-a
n=0
until crm_mon -1 | grep -q 'Online: \[ ctl-a ctl-b \]'; do
	n=$((n + 1)); [ $n -lt 60 ] || { crm_mon -1; exit 1; }
	sleep 2
done
```

## Step 9. Pools

This writes to the shared drives.  Run it once, on one controller, and
only for pools that do not exist yet: `zpool import -d /dev/disk/by-id`
lists the pools that do.  The partitioning is the lab's stand-in for a
dual-ported drive's two namespaces; skip it on real drives and name the
namespaces in the vdevs instead.

```sh ctl-a
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	printf 'label: gpt\n,2000MiB\n,\n' | sfdisk -q $d
done
udevadm settle
zpool create -o multihost=on -o cachefile=none -O compression=lz4 tankA \
    mirror /dev/disk/by-id/virtio-shared0-part1 /dev/disk/by-id/virtio-shared1-part1
zfs create -V 1G -o volblocksize=16k tankA/vol1
zpool export tankA
zpool create -o multihost=on -o cachefile=none -O compression=lz4 tankB \
    mirror /dev/disk/by-id/virtio-shared0-part2 /dev/disk/by-id/virtio-shared1-part2
zfs create -V 1G -o volblocksize=16k tankB/vol1
zpool export tankB
```

ctl-b read the partition tables while the drives were blank; it has to
read them again before it can import.

```sh ctl-b
for d in /dev/disk/by-id/virtio-shared0 /dev/disk/by-id/virtio-shared1; do
	blockdev --rereadpt $d
done
udevadm settle
```

## Step 10. Cluster resources

Per controller, a subsystem (the same NQN and serial on both, its own
controller ID range) and a port, each kept off the other controller.
Per pool, a group of the ZFS agent and nvmet-namespace that prefers one
controller and moves to the other when it fails.

Everything is created in a shadow copy of the cluster configuration and
committed in one go.  Created one element at a time, a port can start
before the constraint that orders it after its subsystem exists; it then
finds no subsystem to link, reports success anyway, and the controller
has no listener.

Fencing is left off here because the lab has none.  Read the warning
in `README.md` before running this on real hardware.

```sh ctl-a
crm_attribute --type crm_config --name stonith-enabled --update false
crm_shadow --batch --force --create zfs-nvmet-ha
export CIB_shadow=zfs-nvmet-ha
N=nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha
node() {
	h=$1 o=$2 min=$3 max=$4 pid=$5 addr=$6
	cibadmin --create --scope resources --xml-text "<primitive id=\"sub-$h\" class=\"ocf\" provider=\"heartbeat\" type=\"nvmet-subsystem\"><instance_attributes id=\"sub-$h-ia\"><nvpair id=\"sub-$h-nqn\" name=\"nqn\" value=\"$N\"/><nvpair id=\"sub-$h-serial\" name=\"serial\" value=\"5a46534e564d4554\"/><nvpair id=\"sub-$h-min\" name=\"cntlid_min\" value=\"$min\"/><nvpair id=\"sub-$h-max\" name=\"cntlid_max\" value=\"$max\"/></instance_attributes><operations><op id=\"sub-$h-mon\" name=\"monitor\" interval=\"10s\"/></operations></primitive>"
	cibadmin --create --scope resources --xml-text "<primitive id=\"port-$h\" class=\"ocf\" provider=\"heartbeat\" type=\"nvmet-port\"><instance_attributes id=\"port-$h-ia\"><nvpair id=\"port-$h-id\" name=\"port_id\" value=\"$pid\"/><nvpair id=\"port-$h-addr\" name=\"addr\" value=\"$addr\"/><nvpair id=\"port-$h-nqns\" name=\"nqns\" value=\"$N\"/></instance_attributes><operations><op id=\"port-$h-mon\" name=\"monitor\" interval=\"10s\"/></operations></primitive>"
	cibadmin --create --scope constraints --xml-text "<rsc_location id=\"sub-$h-not-$o\" rsc=\"sub-$h\" node=\"$o\" score=\"-INFINITY\"/>"
	cibadmin --create --scope constraints --xml-text "<rsc_location id=\"port-$h-not-$o\" rsc=\"port-$h\" node=\"$o\" score=\"-INFINITY\"/>"
	cibadmin --create --scope constraints --xml-text "<rsc_order id=\"sub-$h-then-port-$h\" first=\"sub-$h\" then=\"port-$h\"/>"
}
node ctl-a ctl-b 1 999 1 10.10.0.11
node ctl-b ctl-a 1000 1999 2 10.10.0.12
pool() {
	p=$1 prefers=$2 nsid=$3 uuid=$4
	cibadmin --create --scope resources --xml-text "<group id=\"grp-$p\"><primitive id=\"zfs-$p\" class=\"ocf\" provider=\"heartbeat\" type=\"ZFS\"><instance_attributes id=\"zfs-$p-ia\"><nvpair id=\"zfs-$p-pool\" name=\"pool\" value=\"$p\"/><nvpair id=\"zfs-$p-args\" name=\"importargs\" value=\"-d /dev/disk/by-id\"/></instance_attributes><operations><op id=\"zfs-$p-start\" name=\"start\" interval=\"0s\" timeout=\"120s\"/><op id=\"zfs-$p-stop\" name=\"stop\" interval=\"0s\" timeout=\"60s\"/><op id=\"zfs-$p-mon\" name=\"monitor\" interval=\"5s\" timeout=\"30s\"/></operations></primitive><primitive id=\"ns-$p\" class=\"ocf\" provider=\"heartbeat\" type=\"nvmet-namespace\"><instance_attributes id=\"ns-$p-ia\"><nvpair id=\"ns-$p-nqn\" name=\"nqn\" value=\"$N\"/><nvpair id=\"ns-$p-nsid\" name=\"namespace_id\" value=\"$nsid\"/><nvpair id=\"ns-$p-path\" name=\"backing_path\" value=\"/dev/zvol/$p/vol1\"/><nvpair id=\"ns-$p-uuid\" name=\"uuid\" value=\"$uuid\"/><nvpair id=\"ns-$p-nguid\" name=\"nguid\" value=\"$uuid\"/></instance_attributes><operations><op id=\"ns-$p-mon\" name=\"monitor\" interval=\"10s\"/></operations></primitive></group>"
	cibadmin --create --scope constraints --xml-text "<rsc_location id=\"$p-prefers-$prefers\" rsc=\"grp-$p\" node=\"$prefers\" score=\"100\"/>"
}
pool tankA ctl-a 1 6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0001
pool tankB ctl-b 2 6c0a8d2e-0f5e-4b8a-9a52-3d1c2b7f0002
unset CIB_shadow
crm_shadow --batch --force --commit zfs-nvmet-ha
crm_shadow --batch --force --delete zfs-nvmet-ha
```

## Step 11. Wait for the pools

```sh ctl-a
for want in 'ns-tankA.*Started ctl-a' 'ns-tankB.*Started ctl-b'; do
	n=0
	until crm_mon -1 | grep -q "$want"; do
		n=$((n + 1)); [ $n -lt 90 ] || { crm_mon -1 --failcounts; exit 1; }
		sleep 2
	done
done
crm_mon -1
```

## Connecting a host

Not part of the controllers' setup.  A host with native NVMe multipath
connects to both controllers; each namespace is then optimized through
the controller that holds its pool.

```sh host
modprobe nvme-tcp
for a in 10.10.0.11 10.10.0.12; do
	nvme connect -t tcp -a $a -s 4420 -n nqn.2026-10.org.fml.nsrg:zfs-nvmet-ha --ctrl-loss-tmo=-1
done
nvme list-subsys
```
