#!/bin/sh
set -eu

MODULE_DIR=${1:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
KERNEL_RELEASE=$(uname -r)
INSTALL_DIR=${INSTALL_DIR:-/lib/modules/$KERNEL_RELEASE/updates/fnos-iptables-legacy}
MODULES="
x_tables
ip_tables
iptable_filter
iptable_mangle
iptable_nat
iptable_raw
nf_socket_ipv4
nf_socket_ipv6
nf_tproxy_ipv4
nf_tproxy_ipv6
xt_socket
xt_TPROXY
xt_multiport
xt_limit
xt_MASQUERADE
xt_TCPMSS
xt_REDIRECT
"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
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
