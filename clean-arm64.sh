#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KDIR=${KDIR:-/lib/modules/$(uname -r)/build}
CROSS_COMPILE=${CROSS_COMPILE:-}

if [ ! -d "$KDIR" ]; then
    echo "Kernel build directory not found: $KDIR" >&2
    exit 1
fi

make -C "$SCRIPT_DIR" \
    KDIR="$KDIR" \
    KERNEL_SRC="$KDIR" \
    ARCH=arm64 \
    CROSS_COMPILE="$CROSS_COMPILE" \
    clean
