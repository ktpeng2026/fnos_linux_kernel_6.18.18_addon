#!/bin/sh
set -eu

MODULE_DIR=${1:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}

load_one()
{
    module_name=$1
    if grep -q "^${module_name} " /proc/modules; then
        echo "already loaded: $module_name"
        return
    fi
    insmod "$MODULE_DIR/$module_name.ko"
}

modprobe x_tables
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

lsmod | grep -E '^(ip_tables|iptable_(filter|mangle|nat|raw)|nf_(socket|tproxy)_ipv[46]|xt_(TPROXY|socket|multiport|limit|MASQUERADE|TCPMSS|REDIRECT))\b'
