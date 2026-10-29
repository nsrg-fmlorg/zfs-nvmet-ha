#!/bin/sh
# Rebuild AlmaLinux's pacemaker with the matching patch from lab/patches,
# in an AlmaLinux container, and leave the binary RPMs in $OUT
# (work/pcmk-rpms), the source RPM in $OUT/SRPMS, and repodata for dnf.
# joinstall.sh installs them when PCMK_VERSION=patched.
#
#   usage: build-pacemaker.sh [EL] [VERSION]
#
# EL is 9 (the default) or 10.  VERSION is the upstream version to rebuild,
# e.g. 2.1.9; without it, whatever the distribution has now.  2.1.9 comes
# from the 9.6 vault, the release that shipped 2.1.9-1.el9.  The patch is
# lab/patches/pacemaker-<version>-*.patch, where <version> is the source
# RPM's upstream version.  The release gets a ".lab1" so the packages say
# what they are.
set -eu

EL=${1:-9}
VERSION=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
LAB=${LAB:-$(pwd)/work}
OUT=${OUT:-$LAB/pcmk-rpms}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

docker run --rm -e EL="$EL" -e VERSION="$VERSION" \
    -v "$HERE/patches:/patches:ro" -v "$OUT:/out" \
    "docker.io/library/almalinux:$EL" sh -eux -c '
r() { for i in 1 2 3 4 5; do "$@" && return; sleep 20; done; return 1; }
r dnf -y -q install rpm-build dnf-plugins-core git createrepo_c
dnf config-manager --set-enabled crb highavailability
if [ "$VERSION" = 2.1.9 ]; then
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
	srpm=pacemaker-2.1.9-1.el9.src.rpm
	for d in AppStream HighAvailability; do
		curl -fsSL -o /tmp/$srpm "$V/$d/Source/Packages/$srpm" && break
	done
else
	# The distribution source repositories (they point at the vault).
	cd /tmp
	r dnf -y download --source --enablerepo="*-source" pacemaker
	srpm=$(ls pacemaker-*.src.rpm)
fi
rpm -i /tmp/$srpm
spec=/root/rpmbuild/SPECS/pacemaker.spec
ver=$(rpm -qp --qf "%{VERSION}" /tmp/$srpm)
set -- /patches/pacemaker-$ver-*.patch
[ -f "$1" ] || { echo "no patch for pacemaker $ver" >&2; exit 1; }
n=900
for p in "$@"; do
	cp "$p" /root/rpmbuild/SOURCES/
	# %autosetup applies patches by number; 900 and up come after the
	# ones RHEL carries.
	sed -i "/^Source0:/a Patch$n: $(basename "$p")" "$spec"
	n=$((n + 1))
done
sed -i "s/^\(Release:\s*\)\(.*\)%{?dist}/\1\2.lab1%{?dist}/" "$spec"
grep -n "^Patch\|autosetup\|^Release" "$spec"
r dnf -y -q builddep "$spec"
git config --global user.name lab; git config --global user.email lab@localhost
rpmbuild -ba --nocheck "$spec"
cp /root/rpmbuild/RPMS/*/*.rpm /out/
mkdir -p /out/SRPMS
cp /root/rpmbuild/SRPMS/*.src.rpm /out/SRPMS/
createrepo_c -q /out
'
ls -l "$OUT"
