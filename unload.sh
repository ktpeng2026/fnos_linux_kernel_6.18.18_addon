#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script as root." >&2
    exit 1
fi

for module_name in \
    xt_REDIRECT xt_TCPMSS xt_MASQUERADE xt_limit xt_multiport \
    xt_TPROXY xt_socket nf_tproxy_ipv6 nf_tproxy_ipv4 \
    nf_socket_ipv6 nf_socket_ipv4 iptable_raw iptable_nat \
    iptable_mangle iptable_filter ip_tables x_tables
do
    if grep -q "^${module_name} " /proc/modules; then
        echo "unloading: $module_name"
        rmmod "$module_name" || {
            echo "Unable to unload $module_name; it may still be in use." >&2
            exit 1
        }
    fi
done
