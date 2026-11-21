# Copyright (C) 2026 KhillOS
# SPDX-License-Identifier: Apache-2.0

# KhillOS validation product based on the upstream Cuttlefish PC product.
$(call inherit-product, device/google/cuttlefish/vsoc_x86_64_only/pc/aosp_cf.mk)

PRODUCT_NAME := khillos_cf_x86_64_pc
PRODUCT_DEVICE := khillos
PRODUCT_MANUFACTURER := KhillOS
PRODUCT_MODEL := KhillOS x86_64 validation PC

PRODUCT_VENDOR_PROPERTIES += ro.hardware.power=x86
PRODUCT_PRODUCT_PROPERTIES += power.nonboot-cpu-off=1

PRODUCT_PACKAGES += \
    power.x86 \
    x86power_smoke

ifeq ($(TARGET_PRODUCT),khillos_cf_x86_64_pc)
PRODUCT_SOONG_ONLY := $(RELEASE_SOONG_ONLY_CUTTLEFISH)
endif
