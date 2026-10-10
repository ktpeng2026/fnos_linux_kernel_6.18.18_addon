#!/bin/sh
set -eu

KERNEL_SRC=${KERNEL_SRC:-/home/fh/vs_code/linux-6.18.18}
KERNEL_OUT=${KERNEL_OUT:-$KERNEL_SRC/out-arm64-addon}
BASE_CONFIG=${BASE_CONFIG:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/config-6.18.18.c1151-trim}
ARCH=${ARCH:-arm64}
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

mkdir -p "$KERNEL_OUT"
cp "$BASE_CONFIG" "$KERNEL_OUT/.config"

"$KERNEL_SRC/scripts/kconfig/merge_config.sh" \
    -m -O "$KERNEL_OUT" \
    "$KERNEL_OUT/.config" "$SCRIPT_DIR/config.fragment"

make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig
make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
    ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" modules_prepare

cat <<EOF
Prepared kernel output: $KERNEL_OUT

Note: modules_prepare does not create Module.symvers. For CONFIG_MODVERSIONS or
strict modpost checks, copy the exact target kernel's Module.symvers here or
complete a matching kernel/modules build before building the add-on modules.
EOF
