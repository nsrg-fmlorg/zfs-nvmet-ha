#!/bin/sh
# Rebuild AlmaLinux 9's pacemaker-2.1.9-1.el9 with the patches in
# lab/patches/pacemaker-2.1.9-*.patch, in an AlmaLinux 9 container, and
# leave the binary RPMs in $OUT (work/pcmk-rpms).  joinstall.sh installs
# them when PCMK_RPMS points there.
#
# The source RPM and the build dependencies come from the 9.6 vault, the
# release that shipped 2.1.9-1.el9.  The release gets a ".lab1" so the
# packages say what they are.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
LAB=${LAB:-$(pwd)/work}
OUT=${OUT:-$LAB/pcmk-rpms}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

docker run --rm -v "$HERE/patches:/patches:ro" -v "$OUT:/out" \
    docker.io/library/almalinux:9 sh -eux -c '
r() { for i in 1 2 3 4 5; do "$@" && return; sleep 20; done; return 1; }
V=https://vault.almalinux.org/9.6
cat > /etc/yum.repos.d/vault96.repo <<EOF
[v96-baseos]
baseurl=$V/BaseOS/x86_64/os/
gpgcheck=0
[v96-appstream]
baseurl=$V/AppStream/x86_64/os/
gpgcheck=0
[v96-crb]
baseurl=$V/CRB/x86_64/os/
gpgcheck=0
[v96-ha]
baseurl=$V/HighAvailability/x86_64/os/
gpgcheck=0
EOF
r dnf -y -q install rpm-build dnf-plugins-core git
srpm=pacemaker-2.1.9-1.el9.src.rpm
for d in AppStream HighAvailability; do
	curl -fsSL -o /tmp/$srpm "$V/$d/Source/Packages/$srpm" && break
done
rpm -i /tmp/$srpm
spec=/root/rpmbuild/SPECS/pacemaker.spec
n=900
for p in /patches/pacemaker-2.1.9-*.patch; do
	cp "$p" /root/rpmbuild/SOURCES/
	b=$(basename "$p")
	# %autosetup applies patches by number; 900 and up come after the ones RHEL carries.
	sed -i "/^Source0:/a Patch$n: $b" "$spec"
	n=$((n + 1))
done
grep -n "^Patch\|autosetup\|^Release" "$spec"
sed -i "s/^\(Release:\s*\)\(.*\)%{?dist}/\1\2.lab1%{?dist}/" "$spec"
r dnf -y -q builddep "$spec"
git config --global user.name lab; git config --global user.email lab@localhost
rpmbuild -bb --nocheck "$spec"
cp /root/rpmbuild/RPMS/*/*.rpm /out/
'
ls -l "$OUT"
