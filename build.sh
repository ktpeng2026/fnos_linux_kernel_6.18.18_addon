#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KDIR=${KDIR:-/lib/modules/$(uname -r)/build}
ARCH=${ARCH:-arm64}
CROSS_COMPILE=${CROSS_COMPILE:-}
JOBS=${JOBS:-$(nproc)}
KBUILD_MODPOST_WARN=${KBUILD_MODPOST_WARN:-0}

if [ ! -d "$KDIR" ]; then
    echo "Kernel build directory not found: $KDIR" >&2
    exit 1
fi

make -C "$SCRIPT_DIR" \
    KDIR="$KDIR" \
    KERNEL_SRC="$KDIR" \
    ARCH="$ARCH" \
    CROSS_COMPILE="$CROSS_COMPILE" \
    KBUILD_MODPOST_WARN="$KBUILD_MODPOST_WARN" \
    -j"$JOBS"
