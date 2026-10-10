# Linux 6.18.18 legacy iptables add-on modules

This directory builds the IPv4 legacy iptables table modules removed from the
6.18.18 kernel configuration when `CONFIG_NETFILTER_XTABLES_LEGACY` is disabled.

## Why the modules are absent

The 6.18.18 config contains `CONFIG_IP_NF_IPTABLES=m`, but also contains:

```text
# CONFIG_NETFILTER_XTABLES_LEGACY is not set
```

In Linux 6.18.18, `ip_tables.ko` and the `iptable_*` table modules are selected
through `CONFIG_IP_NF_IPTABLES_LEGACY`, which depends on
`CONFIG_NETFILTER_XTABLES_LEGACY`. Consequently they are not built by the
original configuration.

`lsmod` only reports currently loaded modules. Missing `xt_*`, `nf_*`, or other
entries in `lsmod` do not by themselves prove that the corresponding `.ko` file
is absent. Check the target with `find /lib/modules/$(uname -r) -name '*.ko*'` or
`modinfo MODULE_NAME`.

## Files built

- `x_tables.ko` with the legacy table API enabled
- `ip_tables.ko`
- `iptable_filter.ko`
- `iptable_mangle.ko`
- `iptable_nat.ko`
- `iptable_raw.ko`
- `nf_socket_ipv4.ko`, `nf_socket_ipv6.ko`
- `nf_tproxy_ipv4.ko`, `nf_tproxy_ipv6.ko`
- `xt_socket.ko`, `xt_TPROXY.ko`
- `xt_multiport.ko`, `xt_limit.ko`
- `xt_MASQUERADE.ko`, `xt_TCPMSS.ko`, `xt_REDIRECT.ko`

The supplied 6.18.18 config already sets all requested `xt_*`, `nf_socket_*`,
and `nf_tproxy_*` options to `m`. Their absence from `lsmod` normally means
they were not loaded, not that they were excluded from the kernel build.
`iptable_filter.ko` is different: it is excluded because the legacy xtables
switch is disabled. The add-on includes all requested modules so they can be
built and deployed as one matching set.

## Required x_tables replacement

The fnOS 6.18.18 `x_tables.ko` was built with
`CONFIG_NETFILTER_XTABLES_LEGACY=n`. It therefore does not export legacy symbols
such as `xt_register_table`, `xt_replace_table`, `xt_recseq`, and
`xt_percpu_counter_alloc`. Building only `ip_tables.ko` produces modpost
undefined-symbol warnings and the resulting module cannot be loaded.

This add-on therefore also builds `x_tables.ko`, compiling the same 6.18.18
source with the legacy table API enabled. The generated `x_tables.ko` must
replace the target's original module; it must not be loaded alongside the old
module because both export the normal xtables symbols.

Before replacing anything, locate and back up the installed module:

```sh
modinfo -n x_tables
cp "$(modinfo -n x_tables)" "$(modinfo -n x_tables).backup"
```

Install all generated modules under a dedicated directory, but replace the
module selected by `modprobe x_tables` with the new `x_tables.ko`, then run
`depmod -a` and reboot. Do not attempt to unload a busy `x_tables` module on a
running firewall/NAT system.

After reboot, verify the required API before loading `ip_tables`:

```sh
grep -w xt_register_table /proc/kallsyms
modprobe ip_tables
```

If `/proc/kallsyms` hides addresses, the symbol name should still be visible to
root. The supplied `load.sh` performs this check and refuses to continue when
the old non-legacy `x_tables` module is loaded.

## Prepare a matching ARM64 kernel tree

The module ABI must exactly match the running 6.18.18 kernel, including config,
compiler ABI, local version, symbol versions, and vendor patches.

```sh
cd /home/fh/vs_code/linuxkernel/fnos_linux_kernel_6.18.18_addon
KERNEL_SRC=/home/fh/vs_code/linux-6.18.18 \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
./prepare-kernel.sh
```

The prepared output defaults to:

```text
/home/fh/vs_code/linux-6.18.18/out-arm64-addon
```

`modules_prepare` does not generate `Module.symvers`. Copy the exact
`Module.symvers` used for the running target kernel into that output directory,
or perform the matching full kernel/modules build. This is mandatory when the
target uses `CONFIG_MODVERSIONS=y` and strongly recommended in all cases.

## Build

Copy the complete add-on directory to the ARM64 target. In particular, the
updated Makefile requires `src/x_tables.c`; copying only the Makefile and shell
scripts results in `No rule to make target 'src/x_tables.o'`.

Verify the file before compiling:

```sh
test -f src/x_tables.c && echo "x_tables source present"
```

On the ARM64 target, the scripts use the running kernel build directory by
default:

```sh
KDIR=/lib/modules/"$(uname -r)"/build
```

```sh
cd /home/fh/vs_code/linuxkernel/fnos_linux_kernel_6.18.18_addon
./build-arm64.sh
```

Equivalent direct command:

```sh
KDIR=/lib/modules/"$(uname -r)"/build
make -C "$KDIR" \
    M=/home/fh/vs_code/linuxkernel/fnos_linux_kernel_6.18.18_addon \
    ARCH=arm64 \
    CROSS_COMPILE= \
    -j"$(nproc)" \
    modules
```

The default is a strict modpost build (`KBUILD_MODPOST_WARN=0`) because the
target kernel build environment is expected to contain the matching
`Module.symvers`.

Messages such as `Skipping BTF generation ... due to unavailability of
vmlinux` do not prevent module loading. They only mean detached BTF metadata was
not generated. The undefined legacy `xt_*` symbols are the issue that must be
fixed by replacing `x_tables.ko`.

Clean ARM64 build outputs:

```sh
cd /home/fh/vs_code/linuxkernel/fnos_linux_kernel_6.18.18_addon
./clean-arm64.sh
```

Equivalent direct clean command:

```sh
KDIR=/lib/modules/"$(uname -r)"/build
make -C "$KDIR" \
    M=/home/fh/vs_code/linuxkernel/fnos_linux_kernel_6.18.18_addon \
    ARCH=arm64 \
    CROSS_COMPILE= \
    clean
```

If compiling natively on the ARM64 target, use:

```sh
KERNEL_SRC=/lib/modules/"$(uname -r)"/build \
ARCH=arm64 \
CROSS_COMPILE= \
./build.sh
```

## Install and load on the target

Copy the generated `.ko` files to the target. Before loading, verify the ABI:

```sh
uname -r
modinfo ./ip_tables.ko | grep vermagic
```

Load dependencies and modules as root:

```sh
./load.sh /path/to/modules
```

For a non-persistent test, unload them in reverse dependency order with:

```sh
./unload.sh
```

Modules loaded only with `insmod`, `modprobe`, or `load.sh` are removed by a
reboot. They are not automatically loaded again unless they are installed under
`/lib/modules/$(uname -r)`, indexed by `depmod`, and requested by a boot service,
firewall configuration, `/etc/modules`, or a file under `/etc/modules-load.d/`.

For persistent installation, place the files under
`/lib/modules/$(uname -r)/extra/iptables-legacy/`, run `depmod -a`, then use
`modprobe iptable_filter`, `modprobe iptable_mangle`, `modprobe iptable_nat`,
and `modprobe iptable_raw`.

Do not use `insmod -f` to bypass a vermagic or symbol-version mismatch.
