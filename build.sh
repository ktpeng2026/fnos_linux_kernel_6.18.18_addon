#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KDIR=${KDIR:-/lib/modules/$(uname -r)/build}
ARCH=${ARCH:-arm64}
CROSS_COMPILE=${CROSS_COMPILE:-}
JOBS=${JOBS:-$(nproc)}
KBUILD_MODPOST_WARN=${KBUILD_MODPOST_WARN:-0}
REQUIRED_SOURCES="
src/x_tables.c
src/ip_tables.c
src/iptable_filter.c
src/iptable_mangle.c
src/iptable_nat.c
src/iptable_raw.c
"

if [ ! -d "$KDIR" ]; then
    echo "Kernel build directory not found: $KDIR" >&2
    exit 1
fi

for source_file in $REQUIRED_SOURCES; do
    if [ ! -f "$SCRIPT_DIR/$source_file" ]; then
        echo "Required source file not found: $SCRIPT_DIR/$source_file" >&2
        echo "Copy the complete fnos_linux_kernel_6.18.18_addon directory to this machine." >&2
        exit 1
    fi
done

make -C "$SCRIPT_DIR" \
    KDIR="$KDIR" \
    KERNEL_SRC="$KDIR" \
    ARCH="$ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    KBUILD_MODPOST_WARN="$KBUILD_MODPOST_WARN" \
    -j"$JOBS"

if [ "${SAVE_MODULES:-1}" = 1 ]; then
    "$SCRIPT_DIR/save-modules.sh" "$SCRIPT_DIR"
fi
