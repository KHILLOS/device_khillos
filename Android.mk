# KhillOS live-media targets, following the BlissOS GRUB/ISO boot method.
LOCAL_PATH := $(call my-dir)

KHILLOS_LIVE_ISO := $(PRODUCT_OUT)/khillos-android17-live.iso
KHILLOS_LIVE_ISO_INPUTS := \
    $(PRODUCT_OUT)/kernel \
    $(PRODUCT_OUT)/super.img \
    $(PRODUCT_OUT)/boot.img \
    $(PRODUCT_OUT)/init_boot.img \
    $(PRODUCT_OUT)/vendor_boot.img \
    $(PRODUCT_OUT)/vbmeta.img \
    $(PRODUCT_OUT)/vbmeta_system.img \
    $(PRODUCT_OUT)/vbmeta_vendor_dlkm.img \
    $(PRODUCT_OUT)/vbmeta_system_dlkm.img \
    $(LOCAL_PATH)/build_live_iso.sh \
    $(LOCAL_PATH)/build_live_system_disk.sh \
    $(LOCAL_PATH)/live/init \
    $(LOCAL_PATH)/live/byname_helper.c \
    $(LOCAL_PATH)/live/grub.cfg

$(KHILLOS_LIVE_ISO): $(KHILLOS_LIVE_ISO_INPUTS)
	@echo "----- Making KhillOS live ISO -----"
	SUPER_RAW="$(KHILLOS_SUPER_RAW)" bash $(LOCAL_PATH)/build_live_iso.sh $(PRODUCT_OUT) $@

.PHONY: iso_img blissify
iso_img: $(KHILLOS_LIVE_ISO)
blissify: iso_img
