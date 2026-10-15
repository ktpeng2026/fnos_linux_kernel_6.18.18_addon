#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KERNEL_RELEASE=$(uname -r)
MODULE_DIR=${1:-$SCRIPT_DIR/releases/$KERNEL_RELEASE/$(uname -m)}
INSTALL_DIR=${INSTALL_DIR:-/lib/modules/$KERNEL_RELEASE/updates/fnos-iptables-legacy}

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

if [ "$(uname -m)" != aarch64 ]; then
    echo "This package is for aarch64, not $(uname -m)." >&2
    exit 1
fi

if [ ! -f "$MODULE_DIR/modules.list" ] || [ ! -f "$MODULE_DIR/SHA256SUMS" ]; then
    echo "Incomplete release bundle: $MODULE_DIR" >&2
    echo "Build on the ARM device or download the complete releases/<kernel>/aarch64 directory." >&2
    exit 1
fi

cmp -s "$SCRIPT_DIR/modules.list" "$MODULE_DIR/modules.list" || {
    echo "Module list differs from this installer; use a matching release bundle." >&2
    exit 1
}

(cd "$MODULE_DIR" && sha256sum -c SHA256SUMS) || {
    echo "Bundle checksum verification failed; nothing was installed." >&2
    exit 1
}

MODULES=$(cat "$SCRIPT_DIR/modules.list")
expected_vermagic=$(modinfo -F vermagic "$MODULE_DIR/x_tables.ko")
system_module=$(modinfo -n x_tables)
system_vermagic=$(modinfo -F vermagic "$system_module")
if [ "$expected_vermagic" != "$system_vermagic" ]; then
    echo "Full vermagic differs from the installed kernel x_tables module:" >&2
    echo "  bundle: $expected_vermagic" >&2
    echo "  system: $system_vermagic" >&2
    exit 1
fi

for module_name in $MODULES; do
    module_file="$MODULE_DIR/$module_name.ko"
    if [ ! -f "$module_file" ]; then
        echo "Required module not found: $module_file" >&2
        exit 1
    fi

    module_release=$(modinfo -F vermagic "$module_file" | awk '{print $1}')
    if [ "$module_release" != "$KERNEL_RELEASE" ]; then
        echo "Kernel release mismatch: $module_file" >&2
        echo "  module:  $module_release" >&2
        echo "  running: $KERNEL_RELEASE" >&2
        exit 1
    fi
    if [ "$(modinfo -F vermagic "$module_file")" != "$expected_vermagic" ]; then
        echo "Inconsistent vermagic: $module_file" >&2
        exit 1
    fi
done

mkdir -p "$INSTALL_DIR"
for module_name in $MODULES; do
    install -m 0644 "$MODULE_DIR/$module_name.ko" "$INSTALL_DIR/$module_name.ko"
done

depmod -a "$KERNEL_RELEASE"

selected_path=$(modinfo -n x_tables)
case "$selected_path" in
    "$INSTALL_DIR"/x_tables.ko)
        ;;
    *)
        echo "Installation completed, but modprobe does not select the add-on x_tables:" >&2
        echo "  selected: $selected_path" >&2
        echo "  expected: $INSTALL_DIR/x_tables.ko" >&2
        echo "Do not reboot until module selection is corrected." >&2
        exit 1
        ;;
esac

echo "Modules installed in: $INSTALL_DIR"
echo "modprobe will select: $selected_path"
echo "Reboot is required because the old x_tables module is currently loaded."
echo "After reboot, run: $MODULE_DIR/load.sh $INSTALL_DIR"
