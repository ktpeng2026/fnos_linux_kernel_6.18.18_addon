#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

KDIR=${KDIR:-/lib/modules/$(uname -r)/build} \
ARCH=arm64 \
CROSS_COMPILE=${CROSS_COMPILE:-} \
JOBS=${JOBS:-$(nproc)} \
exec "$SCRIPT_DIR/build.sh"
