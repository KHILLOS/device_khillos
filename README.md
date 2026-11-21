# KhillOS x86_64 validation product

`khillos_cf_x86_64_pc` inherits the upstream Android 17 Cuttlefish PC product and adds the x86power HAL, its supervised smoke executable, the two properties required before boot, and narrowly scoped SELinux policy. The dedicated `PRODUCT_DEVICE := khillos` BoardConfig inherits the upstream x86_64 board; generated files are under `out/target/product/khillos`.

The product-owned `power.nonboot-cpu-off` control is declared once as `system_public_prop` in system_ext public policy so product and vendor rules can reference the same type. Its value remains an arbitrary string to preserve `property_get_bool` fallback behavior. Vendor property-namespace checks remain enabled.

- `ro.hardware.power=x86`
- `power.nonboot-cpu-off=1`

This is validation infrastructure, not a BlissOS ISO and not evidence of a successful boot. Build with separate lunch arguments:

```sh
source build/envsetup.sh
lunch khillos_cf_x86_64_pc cp2a userdebug
m -j8
```

The current AOSP build is allowed to finish first. The KhillOS product then reuses its intermediates and replaces the product images in the same output tree, avoiding a second full build. The AOSP-only image is not needed for this validation.
