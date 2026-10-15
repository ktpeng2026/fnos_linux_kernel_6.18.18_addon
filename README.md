# fnOS 6.18.18 ARM64 legacy iptables 模块

本工程在运行目标内核的 ARM64 设备上编译 17 个 `.ko`。原 fnOS 配置关闭了
`CONFIG_NETFILTER_XTABLES_LEGACY`；`ip_tables` 需要的 `xt_register_table` 等符号
不由原版 `x_tables.ko` 导出，因此本工程也编译带 legacy API 的替代版 `x_tables.ko`。
不能让两个同名 `x_tables` 模块同时加载。

## 1. 目标 ARM64 设备准备

确认设备是 `aarch64`，并已安装**与正在运行的 fnOS 内核完全对应**的头文件/
构建树。内核版本、厂商补丁、配置、符号版本、模块签名策略必须匹配；不能只凭
`6.18.18` 主版本或随意安装通用发行版的 `linux-headers` 包。

```sh
uname -m
uname -r
KDIR=/lib/modules/"$(uname -r)"/build
ls -ld "$KDIR"
test -f "$KDIR/Makefile" && test -f "$KDIR/include/generated/autoconf.h"
test -s "$KDIR/Module.symvers" && echo 'Module.symvers 已就绪'
```

外部模块编译至少需要 `make`、本机 ARM64 `gcc`、`binutils`、`kmod`
（提供 `modinfo`、`depmod`、`modprobe`、`insmod`）、`coreutils`
（提供 `sha256sum`、`install`）、`tar`、`gzip`，以及上述**精确匹配**的
内核构建树。Debian/Ubuntu/兼容 `apt` 的 fnOS 可先检查仓库及包是否可用，
再执行：

```sh
apt update
apt install build-essential binutils kmod coreutils tar gzip
```

若系统没有 `apt`，用其自带包管理器安装同名工具；**不要**为解决编译问题
擅自替换 fnOS 的内核或头文件。`pahole`（通常由 `dwarves` 提供）以及
`vmlinux` 仅在需要生成模块 BTF 时才考虑，普通加载不依赖它们。若需要重新
生成内核配置/完整构建树，才可能还需要 `bc`、`bison`、`flex`、
`libssl-dev`、`libelf-dev` 等依赖；这不是本工程使用已准备好 `$KDIR`
直接编译的必要安装清单。

```sh
command -v make gcc ld modinfo depmod sha256sum install tar
gcc --version | head -1
```

内核文档指出 `modules_prepare` **不会**生成 `Module.symvers`。如果缺失，
应获取目标内核完整构建所产生的对应文件，而非用
`KBUILD_MODPOST_WARN=1` 的警告产物直接部署。

## 2. 本机编译与清理

将**完整**工程复制到目标机（包括 `src/x_tables.c`、`Makefile`、脚本和
`modules.list`），例如放在 `/fnos_linux_kernel_6.18.18_addon`：

```sh
cd /fnos_linux_kernel_6.18.18_addon
test -f src/x_tables.c
./build-arm64.sh
```

`build-arm64.sh` 默认使用 `KDIR=/lib/modules/$(uname -r)/build`、
`ARCH=arm64`、`CROSS_COMPILE=`，并执行严格的 modpost 检查。
若头文件目录不在默认位置，可显式指定：

```sh
KDIR=/实际/匹配的/内核构建目录 ./build-arm64.sh
```

等价的手动编译命令（**不自动归档**）：

```sh
KDIR=/lib/modules/"$(uname -r)"/build
make -C "$KDIR" M="$PWD" ARCH=arm64 CROSS_COMPILE= -j"$(nproc)" modules
```

清理及重新编译：

```sh
./clean-arm64.sh
./build-arm64.sh
```

`Skipping BTF generation ... due to unavailability of vmlinux` 仅表示未附加
BTF 调试信息；`undefined symbol`、`ERROR: modpost`、`invalid module format`
或加载时的 `Unknown symbol` 则必须排查，不能用 `insmod -f` 强行绕过。

## 3. 按内核版本保存，供其他设备下载

成功执行 `./build-arm64.sh` 后，会自动将全部 17 个 `.ko` 复制到：

```text
releases/<完整 uname -r>/aarch64/
```

目录内还有 `modules.list` 和 `SHA256SUMS`。如果已经编译好但尚未归档：

```sh
./save-modules.sh
tar -czf "$(uname -r)-aarch64-modules.tar.gz" -C releases "$(uname -r)"
```

将压缩包以及**相同工程版本**的 `install-modules.sh`、`modules.list`、
`uninstall-modules.sh` 一起传到另一台 ARM64 设备。目标机无须安装编译工具，
但必须是相同的 fnOS 内核构建/ABI；`uname -r` 相同仅是第一道检查。

```sh
mkdir -p releases
tar -xzf <下载的完整文件名>.tar.gz -C releases
./install-modules.sh
```

安装脚本会检查完整 SHA-256、架构、每个模块的内核 release 与完整
vermagic，以及本机已安装的 `x_tables.ko` 的 vermagic。检查失败则不会
复制模块；通过检查仍不等于保证符号 CRC/签名策略一致，首次重启应检查
`dmesg`。不要混用不同构建批次的 `.ko`。

## 4. 安装、重启、验证与回退

在本机编译后同样使用第 3 步的归档目录安装；**不要再执行旧的
`./install-modules.sh .`**：

```sh
cd /fnos_linux_kernel_6.18.18_addon
./install-modules.sh
modinfo -n x_tables
```

安装脚本将模块放到 `/lib/modules/$(uname -r)/updates/fnos-iptables-legacy/`，
执行 `depmod` 并确认下次 `modprobe` 优先选择新增的 `x_tables.ko`；
不覆盖系统原始模块。由于旧的 `x_tables` 往往正被防火墙使用，**不要在
运行中强制卸载它**。确认安装成功且做好设备恢复准备后重启：

```sh
reboot
```

开机网络/防火墙规则可能自动请求这些模块，因此重启后即使未执行 `load.sh`
也可能在 `lsmod` 中看到它们，这是正常的。检查：

```sh
modinfo -n x_tables
grep -w xt_register_table /proc/kallsyms
lsmod | grep -E '^(x_tables|ip_tables|iptable_|xt_TPROXY|xt_socket)'
dmesg | grep -Ei 'unknown symbol|invalid module|module verification|x_tables|ip_tables'
```

若重启后尚未自动加载，且系统环境允许，可手工执行
`./load.sh /lib/modules/"$(uname -r)"/updates/fnos-iptables-legacy`。
模块正在被规则或其他模块使用时不要运行 `unload.sh`。

需要回退时执行 `./uninstall-modules.sh` 和 `reboot`；卸载脚本只删除本工程
安装在 updates 下的 `.ko` 并重建模块索引，不覆盖系统原始模块。

## 模块清单

`x_tables`、`ip_tables`、`iptable_filter`、`iptable_mangle`、
`iptable_nat`、`iptable_raw`、`nf_socket_ipv4`、`nf_socket_ipv6`、
`nf_tproxy_ipv4`、`nf_tproxy_ipv6`、`xt_socket`、`xt_TPROXY`、
`xt_multiport`、`xt_limit`、`xt_MASQUERADE`、`xt_TCPMSS`、`xt_REDIRECT`。
`lsmod` 只显示已加载模块，不能据此判断某 `.ko` 是否已构建。
