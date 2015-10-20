################################################################################
#
# CRIU
#
################################################################################

CRIU_VERSION = v1.7
CRIU_SITE = $(call github,xemul,criu,$(CRIU_VERSION))
CRIU_DEPENDENCIES = host-protobuf-c host-protobuf
CRIU_LICENSE = GPLv2 (programs), LGPLv2.1 (libraries)
CRIU_LICENSE_FILES = COPYING

define CRIU_BUILD_CMDS
  $(RM) $(@D)/protobuf/google/protobuf/descriptor.proto
  cp $(HOST_DIR)/usr/include/google/protobuf/descriptor.proto $(@D)/protobuf/google/protobuf/
  $(TARGET_MAKE_ENV) $(MAKE) CC="$(HOSTCC) -idirafter $(HOST_DIR)/usr/include $(HOST_LDFLAGS)" \
    AR="$(HOSTAR)" -C $(@D) -j 1 criu
endef

define CRIU_INSTALL_TARGET_CMDS
  $(INSTALL) -D -m 0755 $(@D)/criu $(TARGET_DIR)/usr/sbin
endef

$(eval $(generic-package))
