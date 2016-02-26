KERNEL_VERSION  := 4.3.6
BUSYBOX_VERSION := 1.24.1

TARGETS := output/rootfs.tar.xz output/bzImage output/docker-root.iso output/docker-root.img
SOURCES := Dockerfile \
	configs/buildroot.config \
	configs/busybox.config \
	configs/kernel.config \
	configs/user.config \
	configs/isolinux.cfg \
	overlay/etc/cron/cron.hourly/logrotate \
	overlay/etc/cron/crontabs/root \
	overlay/etc/init.d/docker \
	overlay/etc/init.d/rcK \
	overlay/etc/init.d/S90crond \
	overlay/etc/logrotate.d/docker \
	overlay/etc/profile.d/bash_completion.sh \
	overlay/etc/profile.d/bashrc.sh \
	overlay/etc/profile.d/colorls.sh \
	overlay/etc/profile.d/optbin.sh \
	overlay/etc/sudoers.d/docker \
	overlay/etc/resolv.conf.tail \
	overlay/etc/sysctl.conf \
	overlay/sbin/respawn \
	overlay/sbin/shutdown \
	overlay/var/db/ntp-kod \
	overlay/init \
	patches/glibc/2.21/0001-fix-CVE-2015-7547.patch \
	patches/openssh.patch \
	scripts/build.sh \
	scripts/post_build.sh \
	scripts/post_image.sh

BUILD_IMAGE     := docker-root-builder
BUILD_CONTAINER := docker-root-built

BUILT := `docker ps -aq -f name=$(BUILD_CONTAINER) -f exited=0`
STR_CREATED := $$(docker inspect -f '{{.Created}}' $(BUILD_IMAGE) 2>/dev/null)
IMG_CREATED := $(shell scripts/stamptounix $(STR_CREATED))

CCACHE_DIR := /mnt/sda1/ccache

all: $(TARGETS)

$(TARGETS): build | output
	docker cp $(BUILD_CONTAINER):/build/buildroot/output/images/$(@F) output/

build: $(SOURCES) | .dl
	$(eval SRC_UPDATED=$$(shell scripts/latestmtime $^))
	@if [ "$(SRC_UPDATED)" -gt "$(IMG_CREATED)" ]; then \
		set -e; \
		find . -type f -name '.DS_Store' | xargs rm -f; \
		docker build -t $(BUILD_IMAGE) .; \
		if [ "$(IMG_CREATED)" -gt "$(SRC_UPDATED)" ]; then \
			(docker rm -f $(BUILD_CONTAINER) || true); \
		fi; \
	fi
	@if [ "$(BUILT)" == "" ]; then \
		set -e; \
		(docker rm -f $(BUILD_CONTAINER) || true); \
		docker run --privileged -v $(CCACHE_DIR):/build/buildroot/ccache \
			-v /vagrant/.dl:/build/buildroot/dl --name $(BUILD_CONTAINER) $(BUILD_IMAGE); \
	fi

output .ccache .dl:
	mkdir -p $@

clean:
	$(RM) -r output
	-docker rm -f $(BUILD_CONTAINER)

distclean: clean
	$(RM) -r .ccache .dl
	-docker rmi $(BUILD_IMAGE)
	vagrant destroy -f
	$(RM) -r .vagrant

.PHONY: all build clean distclean

vagrant:
	-vagrant resume docker-root
	-vagrant reload docker-root
	vagrant up --no-provision docker-root
	vagrant provision docker-root
	vagrant ssh docker-root -c 'sudo mkdir -p $(CCACHE_DIR)'

dev:
	-vagrant resume docker-root-$@
	-vagrant reload docker-root-$@
	vagrant up --no-provision docker-root-$@
	vagrant provision docker-root-$@
	vagrant ssh docker-root-$@ -c 'sudo mkdir -p $(CCACHE_DIR)'

config: | output
	docker cp $(BUILD_CONTAINER):/build/buildroot/.config output/
	mv output/.config output/buildroot.config
	-diff configs/buildroot.config output/buildroot.config
	docker cp $(BUILD_CONTAINER):/build/buildroot/output/build/busybox-$(BUSYBOX_VERSION)/.config output/
	mv output/.config output/busybox.config
	-diff configs/busybox.config output/busybox.config
	docker cp $(BUILD_CONTAINER):/build/buildroot/output/build/linux-$(KERNEL_VERSION)/.config output/
	mv output/.config output/kernel.config
	-diff configs/kernel.config output/kernel.config

install:
	cp output/bzImage ../docker-root-packer/iso/
	cp output/rootfs.tar.xz ../docker-root-packer/iso/
	cp output/kernel.config ../docker-root-packer/iso/
	cp output/docker-root.iso ../docker-root-packer/box/
	cp output/docker-root.img ../docker-root-packer/box/
	cp configs/isolinux.cfg ../docker-root-packer/iso/

.PHONY: vagrant dev config install
