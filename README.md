# KhillOS x86_64 validation product

`khillos_cf_x86_64_pc` inherits the upstream Android 17 Cuttlefish PC product and adds the x86power HAL, its supervised smoke executable, the two properties required before boot, and narrowly scoped SELinux policy. The dedicated `PRODUCT_DEVICE := khillos` BoardConfig inherits the upstream x86_64 board; generated files are under `out/target/product/khillos`.

The product-owned `power.nonboot-cpu-off` control is declared once as `system_public_prop` in system_ext public policy so product and vendor rules can reference the same type. Its value remains an arbitrary string to preserve `property_get_bool` fallback behavior. Vendor property-namespace checks remain enabled.

- `ro.hardware.power=x86`
- `power.nonboot-cpu-off=1`

Build the Android images and BlissOS-method live ISO with separate lunch arguments:

```sh
source build/envsetup.sh
lunch khillos_cf_x86_64_pc cp2a userdebug
m blissify iso_img -j8
```

`iso_img` is a Soong genrule and `blissify` is its phony dependency. The ISO uses GRUB **Live Boot Android**, a raw-extent EROFS container, and a GPT system image. A static helper restores by-name block nodes after Android mounts its fresh `/dev` tmpfs. For QEMU validation, create the separate writable data disk and use the host runner:

```sh
bash device/khillos/build_live_data_disk.sh \
    out/target/product/khillos /mnt/aosp/UPSTREAM/guest/live-data.img
bash /mnt/aosp/KHILLOS_TOOLS/run_live_iso_guest.sh \
    /mnt/aosp/KHILLOS_NOTES/hardware/x86power/live-iso
```

The behavior-specific live boot passed: upstream Power AIDL VTS reports 9 passed, 14 expected skips, and 0 failures; direct AIDL CPU transitions and all legacy smoke cases pass with exact restoration. Evidence is in `/mnt/aosp/KHILLOS_NOTES/hardware/x86power/live-iso-final-verification.md` and its referenced logs. A separate `SystemSensorManager.nativeCreate` watchdog prevents a stable full-framework claim; no SELinux or validation check is disabled.
