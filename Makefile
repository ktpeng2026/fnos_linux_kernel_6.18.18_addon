KDIR ?= /lib/modules/$(shell uname -r)/build
KERNEL_SRC ?= $(KDIR)
ARCH ?= arm64
CROSS_COMPILE ?=
KBUILD_MODPOST_WARN ?= 0

obj-m += ip_tables.o
obj-m += x_tables.o
obj-m += iptable_filter.o
obj-m += iptable_mangle.o
obj-m += iptable_nat.o
obj-m += iptable_raw.o
obj-m += nf_socket_ipv4.o
obj-m += nf_socket_ipv6.o
obj-m += nf_tproxy_ipv4.o
obj-m += nf_tproxy_ipv6.o
obj-m += xt_TPROXY.o
obj-m += xt_socket.o
obj-m += xt_multiport.o
obj-m += xt_limit.o
obj-m += xt_MASQUERADE.o
obj-m += xt_TCPMSS.o
obj-m += xt_REDIRECT.o

ip_tables-y := src/ip_tables.o
x_tables-y := src/x_tables.o
iptable_filter-y := src/iptable_filter.o
iptable_mangle-y := src/iptable_mangle.o
iptable_nat-y := src/iptable_nat.o
iptable_raw-y := src/iptable_raw.o
nf_socket_ipv4-y := src/nf_socket_ipv4.o
nf_socket_ipv6-y := src/nf_socket_ipv6.o
nf_tproxy_ipv4-y := src/nf_tproxy_ipv4.o
nf_tproxy_ipv6-y := src/nf_tproxy_ipv6.o
xt_TPROXY-y := src/xt_TPROXY.o
xt_socket-y := src/xt_socket.o
xt_multiport-y := src/xt_multiport.o
xt_limit-y := src/xt_limit.o
xt_MASQUERADE-y := src/xt_MASQUERADE.o
xt_TCPMSS-y := src/xt_TCPMSS.o
xt_REDIRECT-y := src/xt_REDIRECT.o

# The running fnOS x_tables module was built without this bool option, so it
# does not export the legacy table API required by ip_tables.ko.
CFLAGS_src/x_tables.o += -DCONFIG_NETFILTER_XTABLES_LEGACY

.PHONY: all arm64 clean clean-arm64 install

all:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_MODPOST_WARN=$(KBUILD_MODPOST_WARN) modules

arm64:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_MODPOST_WARN=$(KBUILD_MODPOST_WARN) -j$(shell nproc) modules

clean:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean

clean-arm64:
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) clean

install: all
	$(MAKE) -C $(KERNEL_SRC) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules_install
