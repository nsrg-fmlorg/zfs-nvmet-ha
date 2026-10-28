#!/bin/sh
# Build SPDK on the runner, which runs the same Ubuntu 24.04 as the VMs,
# and pack what the controller VM needs to run nvmf_tgt and drive it:
#
#   work/spdk.tar.gz   build/bin/nvmf_tgt, scripts/rpc.py and python/
#
# SPDK and its bundled DPDK link statically into nvmf_tgt by default
# (CONFIG_SHARED=n), so the VM only needs the system libraries listed in
# lab/spdk.sh.  Building inside the 2-core VM would take far longer.
set -eu

SPDK_TAG=${SPDK_TAG:-v26.09}
LAB=${LAB:-$(pwd)/work}
mkdir -p "$LAB"
[ -f "$LAB/spdk.tar.gz" ] && { echo "spdk.tar.gz present, not rebuilding"; exit 0; }

src=$LAB/spdk-src
rm -rf "$src"
git clone -q --depth 1 --branch "$SPDK_TAG" --recurse-submodules --shallow-submodules \
    https://github.com/spdk/spdk.git "$src"
cd "$src"
sudo scripts/pkgdep.sh > "$LAB/spdk-pkgdep.log" 2>&1 || { tail -n 30 "$LAB/spdk-pkgdep.log"; exit 1; }
# configure --with-uring needs liburing (configure, "--with-uring requires
# liburing"); pkgdep.sh -u would build 2.2 from source, Ubuntu 24.04 ships 2.5.
sudo apt-get install -yq liburing-dev > /dev/null
# io_uring for the bdevs over kernel block devices; nothing that needs
# hardware the VM does not have.
./configure --with-uring --without-crypto --without-vhost --without-virtio \
    --disable-tests --disable-unit-tests --disable-examples > "$LAB/spdk-configure.log" 2>&1 \
    || { tail -n 30 "$LAB/spdk-configure.log"; exit 1; }
make -j"$(nproc)" > "$LAB/spdk-make.log" 2>&1 || { tail -n 40 "$LAB/spdk-make.log"; exit 1; }
ldd build/bin/nvmf_tgt | tee "$LAB/spdk-ldd.txt"
# Ship every shared library nvmf_tgt uses other than glibc's own, so the
# VM needs no extra packages; lab/spdk.sh runs it with LD_LIBRARY_PATH.
mkdir -p lib
awk '$3 ~ /^\// { print $3 }' "$LAB/spdk-ldd.txt" | while read -r so; do
	case ${so##*/} in
	libc.so.*|libm.so.*|ld-linux*|libpthread.so.*|libdl.so.*|librt.so.*) ;;
	*) cp -L "$so" lib/ ;;
	esac
done
ls lib
tar -czf "$LAB/spdk.tar.gz" build/bin/nvmf_tgt scripts/rpc.py python lib
ls -la "$LAB/spdk.tar.gz"
