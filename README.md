# zfs-nvmet-ha

A lab for a two-controller storage box built from parts that already
exist: ZFS for the data, the Linux kernel NVMe-oF target (nvmet) for the
host side, and dual-ported drives that both controllers can reach.

Each pool is owned by one controller at a time (ZFS cannot be imported on
two hosts at once; `multihost=on` enforces that). Both controllers export
the same subsystem, and ANA tells the host which path to use.

`lab/` boots three VMs under KVM (two controllers sharing two raw disks,
and one host) and runs scenarios against them. CI runs them on GitHub
Actions; the job summary carries the measured numbers.

- `lab/failover.sh`: power loss on the active controller while the host
  writes synchronously; reports the host's I/O pause and checks that every
  acknowledged write survived.
