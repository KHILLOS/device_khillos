#!/usr/bin/env bash
# Build the writable companion data disk for KhillOS live-media validation.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s PRODUCT_DIR OUTPUT_IMG\n' "$0" >&2
    exit 2
fi

product=$(readlink -f "$1")
output=$2
host=/mnt/aosp/UPSTREAM/aosp/out/host/linux-x86/bin
work=${output%.img}-inputs
mib=1048576
start_mib=1
userdata_mib=8192
metadata_mib=64
misc_mib=1

case $product in
    /mnt/aosp/UPSTREAM/aosp/out/target/product/*) ;;
    *) printf 'Invalid product directory: %s\n' "$product" >&2; exit 1 ;;
esac
case $(readlink -m "$output") in
    /mnt/aosp/UPSTREAM/*) ;;
    *) printf 'Output must be under UPSTREAM: %s\n' "$output" >&2; exit 1 ;;
esac
[[ -f $product/userdata.img ]] || { printf 'Missing userdata.img\n' >&2; exit 1; }
[[ -x $host/simg2img ]] || { printf 'Missing simg2img\n' >&2; exit 1; }
command -v sgdisk >/dev/null || { printf 'Missing sgdisk\n' >&2; exit 1; }

rm -rf -- "$work"
mkdir -p "$work"
"$host/simg2img" "$product/userdata.img" "$work/userdata.raw"
truncate -s $((metadata_mib * mib)) "$work/metadata.img"
truncate -s $((misc_mib * mib)) "$work/misc.img"

new_output=$output.new
[[ ! -e $new_output ]] || { printf 'Refusing existing %s\n' "$new_output" >&2; exit 1; }
metadata_start=$((start_mib + userdata_mib))
misc_start=$((metadata_start + metadata_mib))
end_mib=$((misc_start + misc_mib))
truncate -s $(((end_mib + 1) * mib)) "$new_output"
sgdisk --clear \
    --new=1:$((start_mib * 2048)):$((metadata_start * 2048 - 1)) \
    --change-name=1:userdata --typecode=1:8300 \
    --new=2:$((metadata_start * 2048)):$((misc_start * 2048 - 1)) \
    --change-name=2:metadata --typecode=2:8300 \
    --new=3:$((misc_start * 2048)):$((end_mib * 2048 - 1)) \
    --change-name=3:misc --typecode=3:8300 "$new_output"

dd if="$work/userdata.raw" of="$new_output" bs=1M seek=$start_mib conv=notrunc,sparse status=none
dd if="$work/metadata.img" of="$new_output" bs=1M seek=$metadata_start conv=notrunc,sparse status=none
dd if="$work/misc.img" of="$new_output" bs=1M seek=$misc_start conv=notrunc,sparse status=none
sgdisk --verify "$new_output"
sgdisk --print "$new_output"
mv "$new_output" "$output"
sha256sum "$product/userdata.img" "$output" > "$output.sha256"
stat -c 'Live data disk: %n size=%s blocks=%b' "$output"
rm -rf -- "$work"
