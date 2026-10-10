#!/bin/sh
set -eu

MODULE_DIR=${1:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
RUNNING_RELEASE=$(uname -r)
REQUIRED_MODULES="
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
LOADED_BY_SCRIPT=""
LOAD_COMPLETE=0

cleanup_on_failure()
{
    if [ "$LOAD_COMPLETE" -eq 1 ] || [ -z "$LOADED_BY_SCRIPT" ]; then
        return
    fi

    echo "Load failed; attempting to remove modules loaded by this script:" >&2
    for module_name in $LOADED_BY_SCRIPT; do
        echo "  rmmod $module_name" >&2
        rmmod "$module_name" 2>/dev/null || true
    done
}

trap cleanup_on_failure EXIT HUP INT TERM

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

if [ "$(uname -m)" != "aarch64" ]; then
    echo "Unsupported architecture: $(uname -m); expected aarch64." >&2
    exit 1
fi

if [ "$(cat /proc/sys/kernel/modules_disabled)" != "0" ]; then
    echo "Kernel module loading is disabled by kernel.modules_disabled." >&2
    exit 1
fi

for module_name in $REQUIRED_MODULES; do
    module_file="$MODULE_DIR/$module_name.ko"
    if [ ! -f "$module_file" ]; then
        echo "Required module not found: $module_file" >&2
        exit 1
    fi

    module_release=$(modinfo -F vermagic "$module_file" | awk '{print $1}')
    if [ "$module_release" != "$RUNNING_RELEASE" ]; then
        echo "Kernel release mismatch: $module_file" >&2
        echo "  module:  $module_release" >&2
        echo "  running: $RUNNING_RELEASE" >&2
        exit 1
    fi
done

load_one()
{
    module_name=$1
    if grep -q "^${module_name} " /proc/modules; then
        echo "already loaded: $module_name"
        return
    fi

    echo "loading: $module_name"
    insmod "$MODULE_DIR/$module_name.ko"
    LOADED_BY_SCRIPT="$module_name $LOADED_BY_SCRIPT"
}

if grep -q '^x_tables ' /proc/modules; then
    if ! grep -qw xt_register_table /proc/kallsyms; then
        echo "The loaded x_tables module has no legacy table API." >&2
        echo "Do not continue with the currently loaded system x_tables module." >&2
        echo "Install the add-on x_tables.ko, run depmod -a, and reboot first." >&2
        exit 1
    fi
    echo "already loaded with legacy API: x_tables"
else
    load_one x_tables
fi

modprobe nf_conntrack
modprobe nf_nat

load_one ip_tables
load_one iptable_filter
load_one iptable_mangle
load_one iptable_nat
load_one iptable_raw
load_one nf_socket_ipv4
load_one nf_socket_ipv6
load_one nf_tproxy_ipv4
load_one nf_tproxy_ipv6
load_one xt_socket
load_one xt_TPROXY
load_one xt_multiport
load_one xt_limit
load_one xt_MASQUERADE
load_one xt_TCPMSS
load_one xt_REDIRECT

if ! grep -qw xt_register_table /proc/kallsyms; then
    echo "Legacy x_tables API verification failed after loading." >&2
    exit 1
fi

LOAD_COMPLETE=1
trap - EXIT HUP INT TERM

echo "All requested modules loaded successfully."
lsmod | grep -E '^(x_tables|ip_tables|iptable_(filter|mangle|nat|raw)|nf_(socket|tproxy)_ipv[46]|xt_(TPROXY|socket|multiport|limit|MASQUERADE|TCPMSS|REDIRECT))\b'
