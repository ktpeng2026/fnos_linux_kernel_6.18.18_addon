#!/bin/sh
set -eu

KERNEL_RELEASE=$(uname -r)
INSTALL_DIR=${INSTALL_DIR:-/lib/modules/$KERNEL_RELEASE/updates/fnos-iptables-legacy}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

if [ -d "$INSTALL_DIR" ]; then
    rm -f "$INSTALL_DIR"/*.ko
    rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

depmod -a "$KERNEL_RELEASE"
echo "Add-on module files removed. Reboot to return to the original modules."
echo "Current x_tables selection: $(modinfo -n x_tables)"
