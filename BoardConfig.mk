# KhillOS validation board, based on the upstream Cuttlefish x86_64 board.
include device/google/cuttlefish/vsoc_x86_64_only/BoardConfig.mk

BOARD_VENDOR_SEPOLICY_DIRS += device/khillos/sepolicy/vendor
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/khillos/sepolicy/system_ext/public
PRODUCT_PRIVATE_SEPOLICY_DIRS += device/khillos/sepolicy/product/private
