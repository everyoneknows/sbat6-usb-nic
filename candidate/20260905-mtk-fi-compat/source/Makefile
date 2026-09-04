KDIR ?= /home/masataka/projects/sbair6-rce/work/src/linux-5.4.238-ax88179
obj-m += usb_f_ncm.o

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
