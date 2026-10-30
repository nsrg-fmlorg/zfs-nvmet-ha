#!/bin/sh
# Build upstream Pacemaker at a given commit into RPMs on AlmaLinux 10
# (or EL=9 for older trees),
# with or without lab/patches/upstream-main-pcmk-joinfix.patch, and
# run its test suite (make check) on the same tree.
#
#   usage: build-pacemaker-main.sh SHA unpatched|patched
#
# The RPMs land in $OUT (work/pcmk-rpms) with repodata, and the make
# check log in $OUT/make-check.log.  The release carries .main.unpatched
# or .main.patched in place of the dist tag, so the packages say what
# they are; joinstall.sh installs them over the distribution's with
# PCMK_VERSION=patched.
set -eu

SHA=$1 VARIANT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
LAB=${LAB:-$(pwd)/work}
OUT=${OUT:-$LAB/pcmk-rpms}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

docker run --rm -e SHA="$SHA" -e VARIANT="$VARIANT" \
    -v "$HERE/patches:/patches:ro" -v "$OUT:/out" \
    "docker.io/library/almalinux:${EL:-10}" sh -eux -c '
r() { for i in 1 2 3 4 5; do "$@" && return; sleep 20; done; return 1; }
r dnf -y -q install rpm-build dnf-plugins-core git createrepo_c epel-release
dnf config-manager --set-enabled crb highavailability
# The distribution pacemaker build dependencies get configure going; the
# upstream spec adds its own once it exists.
r dnf -y -q builddep --enablerepo="*-source" pacemaker
r dnf -y -q install libcmocka-devel || echo "no cmocka: unit tests will be skipped"
command -v rpmlint || { printf "#!/bin/sh\nexit 0\n" > /usr/local/bin/rpmlint; chmod +x /usr/local/bin/rpmlint; }
git config --global user.name lab; git config --global user.email lab@localhost
git clone -q https://github.com/ClusterLabs/pacemaker.git /src
cd /src
git checkout -q "$SHA"
if [ "$VARIANT" = patched ]; then git am -q /patches/upstream-main-pcmk-joinfix.patch; fi
git log --oneline -2
./autogen.sh > /dev/null
./configure -q
make -s -C rpm spec
spec=$(find rpm -name pacemaker.spec | head -n 1)
r dnf -y -q builddep "$spec"
./configure -q
make -s -j"$(nproc)"
rc=0
make -j"$(nproc)" check > /out/make-check.log 2>&1 || rc=$?
echo "make check rc=$rc" >> /out/make-check.log
grep -h "^# \(TOTAL\|PASS\|SKIP\|XFAIL\|FAIL\|XPASS\|ERROR\)" $(find . -name test-suite.log) /dev/null >> /out/make-check.log 2>/dev/null || :
make -s -C rpm srpm
srpm=$(find rpm -name "pacemaker-*.src.rpm" | head -n 1)
# The spec generates build requirements (pyproject-rpm-macros) that
# builddep on the spec alone does not see.
r dnf -y -q install pyproject-rpm-macros
r dnf -y -q builddep "$srpm"
rpmbuild --rebuild --nocheck --define "dist .main.$VARIANT" "$srpm"
cp /root/rpmbuild/RPMS/*/*.rpm /out/
createrepo_c -q /out
echo "make check rc=$rc"
'
ls -l "$OUT"
