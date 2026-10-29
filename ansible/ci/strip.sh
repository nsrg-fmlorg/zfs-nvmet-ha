#!/bin/sh
# lab/vms.sh's cloud-init already installs ZFS and the cluster stack.
# Take them off again, so the playbook or the manual has to install
# everything itself.
set -eu
for n in ctl-a ctl-b; do
	ssh $n sudo sh -eux <<'EOF'
dnf remove -y pacemaker corosync pcs resource-agents zfs kmod-zfs zfs-dkms zfs-release > /dev/null
dnf config-manager --set-disabled highavailability
rm -f /etc/hostid /etc/mdadm.conf
# The playbook may install another ZFS release; the loaded module would
# then not match the tools.  No pool is imported yet.
modprobe -r zfs spl || :
EOF
done
