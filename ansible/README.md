# Two controllers on AlmaLinux, with Ansible

`site.yml` builds the lab's two-controller layout on two AlmaLinux
machines that share dual-ported NVMe drives: ZFS pools that move between
the controllers under Pacemaker, each pool's zvol exported through the
kernel NVMe-oF target (nvmet) over TCP, and both controllers exporting
one subsystem so that a host using native NVMe multipath has a path
through each.  It is the topology of `lab/pacemaker2.sh`: per controller
a subsystem and a port pinned to it, per pool a group of the ZFS agent
and nvmet-namespace that prefers one controller.

`MANUAL.md` is the same procedure by hand.  The two are kept together
mechanically: the steps of each must match (`ci/check-steps.py`), and CI
builds a lab both ways and runs the same checks on each.

## Warning: fencing is off

`zfs_ha_stonith_enabled` defaults to `false` because the lab has no
fence device.  Do not run real data that way.  Without fencing, a
controller that stops answering the cluster but is still running keeps
its pools imported, and the only thing between that and the other
controller importing them too is ZFS multihost (MMP): the newcomer waits
for the pool's heartbeat to stop before importing.  MMP is the lab's
safety net, not a substitute.  On real hardware, configure a fence
device for each controller (IPMI through `fence_ipmilan`, for
instance), then set `zfs_ha_stonith_enabled: true`.  The playbook does
not create fence devices.

## Use

From a machine with Ansible (ansible-core 2.14 or later) and this
repository:

    cd ansible
    cp -R inventory/example inventory/mine   # then edit hosts.ini
    ansible-playbook -i inventory/mine site.yml

The first run on new drives also needs `-e zfs_ha_create_pools=true`;
see `zfs_ha_create_pools` below.  Run it again whenever the inventory or
variables change; a second run with nothing changed reports no changes.

The inventory names must be the controllers' hostnames, since corosync
and Pacemaker know them by name.

## Variables

Per controller, in the inventory:

| variable | meaning |
|---|---|
| `zfs_ha_addr` | storage network address: the host connects to it, and corosync runs over it |
| `zfs_ha_nodeid` | corosync node id |
| `zfs_ha_hostid` | hostid, distinct per controller, which ZFS multihost depends on |
| `zfs_ha_cntlid_min`, `zfs_ha_cntlid_max` | controller ID range; must not overlap between controllers |
| `zfs_ha_port_id` | nvmet port number |

Cluster-wide, with their defaults in `group_vars/all.yml`; override
them in the inventory's own `group_vars/zfs_ha.yml`, as
`inventory/lab/` does.  (An INI `[zfs_ha:vars]` section ranks below
the playbook's `group_vars` and would be ignored.)

| variable | default | meaning |
|---|---|---|
| `zfs_ha_zfs_style` | `kmod` | OpenZFS's kABI-tracking kmod, or `dkms` to build on the node |
| `zfs_ha_zfs_testing` | true on EL10 | use OpenZFS's testing repositories, where EL10's 2.4 packages are |
| `zfs_ha_nqn`, `zfs_ha_serial` | lab values | subsystem NQN and serial, the same on both controllers |
| `zfs_ha_pools` | tankA, tankB | per pool: name, preferred controller, namespace id and UUID, vdevs by `/dev/disk/by-id`, zvol size |
| `zfs_ha_create_pools` | `false` | create pools that do not exist yet, on the first controller; never destroys one |
| `zfs_ha_partition_disks` | `[]` | lab only: whole disks to split in two partitions, if they have no partition table |
| `zfs_ha_stonith_enabled` | `false` | see the warning above |
| `zfs_ha_corosync_crypto` | `true` | encrypt corosync traffic with a key generated on the first controller |

## What it does

1. OpenZFS's signing key, its `zfs-release` checked against it (3-1
   from `epel-testing/10/` on EL10, 3-0 on EL9), one of its repositories
   (the testing kmod on EL10 by default), and AlmaLinux's
   HighAvailability repository.
2. ZFS, nvme-cli, Pacemaker, corosync, pcs, resource-agents.
3. The hostid, and the boot-time pool import services disabled:
   Pacemaker alone imports pools.
4. `AUTO -all` in `/etc/mdadm.conf`, so that the installed system does
   not assemble md arrays it finds on the shared drives.  The installer
   is not covered by this: `MANUAL.md` explains how to keep it off the
   shared drives.
5. zfs, nvmet and nvmet-tcp loaded at boot.
6. The nvmet agents from `lab/patches/resource-agents-nvmet-ana-cntlid.diff`
   on ClusterLabs/resource-agents 81e937fd, and the ZFS agent from the
   same checkout where the distribution has none.
7. The cluster and NVMe/TCP ports opened, if firewalld is running.
8. corosync (`two_node`, one key for both) and Pacemaker started.
9. Pools created when asked to and absent.
10. The cluster resources, each created when no element with its id
    exists.  An element that exists is left as it is: change one with
    `pcs` or `cibadmin`, not by editing the variables.
11. A wait until each pool runs on its preferred controller.

## What was checked

Measured on AlmaLinux 10.2 (kernel 6.12.0-211.64.1.el10_2), with ZFS
2.4.4 (`kmod-zfs-2.4.4-1.el10`) from OpenZFS's **testing** kmod
repository (`zfs-testing-kmod`), pacemaker 3.0.1, corosync 3.1.10 and
resource-agents 4.16.0.  The EL10 `zfs-release` (3-1, only under
`epel-testing/10/`) labels `zfs-testing-kmod` as deprecated in favour of
`zfs-latest-kmod`, which carries the same 2.4.4 kmod; `zfs-latest-kmod`
was not the one run.  The lab's other scenarios were run with ZFS 2.2
(Ubuntu, AlmaLinux 9) and 2.1 (Debian 12); ZFS multihost's import delay
on 2.4 was not measured here, and may differ from the about 20 s that
2.2 waits at the default settings.

On the lab of `lab/vms.sh` (DISTRO=alma10), in
`.github/workflows/ansible.yml`, starting each time from VMs with the
lab's packages removed again:

- the playbook, then the checks in `ci/check.sh`: both controllers
  online, each pool started on its preferred controller, and a host
  connected to both controllers seeing each namespace optimized through
  the controller that holds its pool;
- the playbook a second time, reporting no changes;
- every block of `MANUAL.md` run in order, then the same checks.

Not checked: real hardware, fencing, DKMS (`zfs_ha_zfs_style: dkms`),
firewalld (the lab's cloud image does not run it), and a failover after
the playbook (that is `lab/pacemaker2.sh`, run on Ubuntu in
`.github/workflows/lab.yml` and on Debian 12 and AlmaLinux 9 in
`.github/workflows/distros.yml`, not on AlmaLinux 10).
