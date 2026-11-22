#!/usr/bin/env bash
# Build a BlissOS-style GRUB live ISO around Android 17 dynamic partitions.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    printf 'Usage: %s PRODUCT_DIR [OUTPUT_ISO]\n' "$0" >&2
    exit 2
fi

product=$(readlink -f "$1")
output=$(readlink -m "${2:-$product/khillos-android17-live.iso}")
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
host=/mnt/aosp/UPSTREAM/aosp/out/host/linux-x86/bin
work=$(readlink -m "${LIVE_WORK:-$product/live_iso_work}")

case $product in
    /mnt/aosp/UPSTREAM/aosp/out/target/product/*) ;;
    *) printf 'Product output must be under UPSTREAM AOSP: %s\n' "$product" >&2; exit 1 ;;
esac
case $output in
    /mnt/aosp/UPSTREAM/aosp/out/*) ;;
    *) printf 'ISO output must stay under the AOSP output directory: %s\n' "$output" >&2; exit 1 ;;
esac
case $work in
    /mnt/aosp/UPSTREAM/aosp/out/*) ;;
    *) printf 'Live work directory must stay under AOSP output: %s\n' "$work" >&2; exit 1 ;;
esac
[[ -d $product ]] || { printf 'Missing product directory: %s\n' "$product" >&2; exit 1; }

for tool in /usr/bin/busybox /usr/bin/cpio /usr/bin/gcc /usr/bin/grub-mkrescue /usr/bin/xorriso \
            "$host/unpack_bootimg" "$host/lz4" "$host/simg2img" "$host/mkfs.erofs"; do
    [[ -x $tool ]] || { printf 'Missing executable host tool: %s\n' "$tool" >&2; exit 1; }
done
for image in kernel init_boot.img vendor_boot.img super.img boot.img vbmeta.img \
             vbmeta_system.img vbmeta_vendor_dlkm.img vbmeta_system_dlkm.img; do
    [[ -f $product/$image ]] || { printf 'Missing product input: %s\n' "$product/$image" >&2; exit 1; }
done

# Remove only this script's known generated work directory.
rm -rf -- "$work"
mkdir -p "$work"/{init_boot,vendor_boot,images,iso/boot/grub,initrd/bin,initrd/dev,initrd/proc,initrd/sys,initrd/mnt,initrd/android,initrd/android_root}
"$host/unpack_bootimg" --boot_img "$product/init_boot.img" --out "$work/init_boot"
"$host/unpack_bootimg" --boot_img "$product/vendor_boot.img" --out "$work/vendor_boot"
"$host/lz4" -d -f "$work/init_boot/ramdisk" "$work/init.cpio"
"$host/lz4" -d -f "$work/vendor_boot/vendor_ramdisk00" "$work/vendor.cpio"

# Device nodes are created by devtmpfs in the live init. Excluding them here
# keeps the ISO build unprivileged while preserving every Android ramdisk file
# needed after that mount.
for stage in init vendor; do
    /usr/bin/cpio -it < "$work/$stage.cpio" 2>/dev/null | /usr/bin/grep -v '^dev/' > "$work/$stage.files"
    (
        cd "$work/initrd/android_root"
        /usr/bin/cpio -idm --unconditional --no-absolute-filenames --no-preserve-owner \
            -E "$work/$stage.files" -F "$work/$stage.cpio"
    )
done

install -m 0755 /usr/bin/busybox "$work/initrd/bin/busybox"
/usr/bin/gcc -static -O2 -Wall -Wextra -Werror \
    -o "$work/initrd/bin/byname_helper" "$source_dir/live/byname_helper.c"
install -m 0755 "$source_dir/live/init" "$work/initrd/init"
install -m 0644 "$source_dir/live/grub.cfg" "$work/iso/boot/grub/grub.cfg"
install -m 0644 "$product/kernel" "$work/iso/kernel"

if [[ -n ${IMAGES_EFS:-} ]]; then
    image_container=$(readlink -f "$IMAGES_EFS")
    [[ -f $image_container ]] || { printf 'Missing IMAGES_EFS: %s\n' "$image_container" >&2; exit 1; }
    ln "$image_container" "$work/iso/images.efs"
else
    if [[ -n ${SUPER_RAW:-} ]]; then
        super_raw=$(readlink -f "$SUPER_RAW")
        [[ -f $super_raw ]] || { printf 'Missing SUPER_RAW: %s\n' "$super_raw" >&2; exit 1; }
    else
        super_raw=$work/super.raw
        "$host/simg2img" "$product/super.img" "$super_raw"
    fi

    # One GPT image lets Android's ueventd recreate all read-only by-name links
    # after first-stage init mounts its fresh /dev tmpfs.
    bash "$source_dir/build_live_system_disk.sh" "$product" "$super_raw" \
        "$work/images/system.raw"
    "$host/mkfs.erofs" -zlz4hc -C65536 "$work/iso/images.efs" "$work/images"
fi

(
    cd "$work/initrd"
    find . -print | LC_ALL=C sort | /usr/bin/cpio -o -H newc --owner=0:0 2>/dev/null | \
        gzip -9 > "$work/iso/initrd.img"
)

if [[ -e $output.new ]]; then
    printf 'Refusing to overwrite temporary output: %s\n' "$output.new" >&2
    exit 1
fi

# The GKI kernel has EROFS but no ISO9660 driver. Keep the initrd small enough
# for GRUB's BIOS limit and locate the EROFS file by its raw ISO extent. The
# fixed-width placeholder preserves the layout between preflight and final ISO.
preflight=$work/preflight.iso
/usr/bin/grub-mkrescue -o "$preflight" "$work/iso"
mapfile -t image_lbas < <(
    /usr/bin/xorriso -indev "$preflight" -find /images.efs -exec report_lba 2>/dev/null | \
        /usr/bin/awk -F'[ ,]+' '/File data lba:/ {print $5}'
)
[[ ${#image_lbas[@]} -eq 1 ]] || { printf 'Expected one images.efs extent\n' >&2; exit 1; }
printf -v image_lba '%010d' "${image_lbas[0]}"
sed -i -E "s/khillos.images_lba=[0-9]{10}/khillos.images_lba=$image_lba/" \
    "$work/iso/boot/grub/grub.cfg"
rm -f -- "$preflight"
/usr/bin/grub-mkrescue -o "$output.new" "$work/iso"
mapfile -t final_lbas < <(
    /usr/bin/xorriso -indev "$output.new" -find /images.efs -exec report_lba 2>/dev/null | \
        /usr/bin/awk -F'[ ,]+' '/File data lba:/ {print $5}'
)
[[ ${#final_lbas[@]} -eq 1 && ${final_lbas[0]} -eq $((10#$image_lba)) ]] || {
    printf 'EROFS extent moved between preflight and final ISO\n' >&2
    exit 1
}
printf 'images.efs LBA=%s byte_offset=%s\n' "$image_lba" "$((10#$image_lba * 2048))" | \
    tee "$output.images-lba"
/usr/bin/xorriso -indev "$output.new" -toc
mv "$output.new" "$output"
sha256sum "$output" > "$output.sha256"
sha256sum "$product/kernel" "$product/init_boot.img" "$product/vendor_boot.img" \
    "$product/super.img" "$product/boot.img" "$product/vbmeta.img" \
    "$product/vbmeta_system.img" "$product/vbmeta_vendor_dlkm.img" \
    "$product/vbmeta_system_dlkm.img" > "$output.sources.sha256"
printf 'KhillOS live ISO: '
stat -c '%n size=%s blocks=%b' "$output"
cat "$output.sha256"

if [[ ${KHILLOS_KEEP_LIVE_WORK:-0} == 1 ]]; then
    printf 'Preserved work directory: %s\n' "$work"
else
    rm -rf -- "$work"
fi
