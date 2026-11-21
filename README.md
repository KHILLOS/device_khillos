# KhillOS x86_64 validation product

`khillos_cf_x86_64_pc` inherits the upstream Android 17 Cuttlefish PC product and adds only the x86power HAL, its supervised smoke executable, and the two properties required before boot:

- `ro.hardware.power=x86`
- `power.nonboot-cpu-off=1`

This is validation infrastructure, not a BlissOS ISO and not evidence of a successful boot. Build with separate lunch arguments:

```sh
source build/envsetup.sh
lunch khillos_cf_x86_64_pc cp2a userdebug
m -j8
```

The current AOSP build is allowed to finish first. The KhillOS product then reuses its intermediates and replaces the product images in the same output tree, avoiding a second full build. The AOSP-only image is not needed for this validation.
