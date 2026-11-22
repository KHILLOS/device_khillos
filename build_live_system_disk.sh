#!/usr/bin/env bash
# Build the read-only GPT system disk embedded in KhillOS live media.
set -euo pipefail

if [[ $# -ne 3 ]]; then
    printf 'Usage: %s PRODUCT_DIR SUPER_RAW OUTPUT_IMG\n' "$0" >&2
    exit 2
fi

product=$1
super_raw=$2
output=$3
mib=1048576
sector=512
start_sector=2048
index=0

labels=(
    boot_a boot_b init_boot_a init_boot_b vendor_boot_a vendor_boot_b
    vbmeta_a vbmeta_b vbmeta_system_a vbmeta_system_b
    vbmeta_vendor_dlkm_a vbmeta_vendor_dlkm_b
    vbmeta_system_dlkm_a vbmeta_system_dlkm_b super
)
images=(
    "$product/boot.img" "$product/boot.img"
    "$product/init_boot.img" "$product/init_boot.img"
    "$product/vendor_boot.img" "$product/vendor_boot.img"
    "$product/vbmeta.img" "$product/vbmeta.img"
    "$product/vbmeta_system.img" "$product/vbmeta_system.img"
    "$product/vbmeta_vendor_dlkm.img" "$product/vbmeta_vendor_dlkm.img"
    "$product/vbmeta_system_dlkm.img" "$product/vbmeta_system_dlkm.img"
    "$super_raw"
)

for image in "${images[@]}"; do
    [[ -f $image ]] || { printf 'Missing input: %s\n' "$image" >&2; exit 1; }
done
command -v sgdisk >/dev/null || { printf 'Missing sgdisk\n' >&2; exit 1; }
new_output=$output.new
[[ ! -e $new_output ]] || { printf 'Refusing existing %s\n' "$new_output" >&2; exit 1; }

sgdisk_args=(--clear)
printf 'label\tpartition\tstart_sector\tend_sector\tinput\n' > "$output.layout.tsv"
for image in "${images[@]}"; do
    label=${labels[$index]}
    size=$(stat -c %s "$image")
    allocated=$(( (size + mib - 1) / mib * mib ))
    sectors=$((allocated / sector))
    end_sector=$((start_sector + sectors - 1))
    partition=$((index + 1))
    sgdisk_args+=(
        --new="$partition:$start_sector:$end_sector"
        --change-name="$partition:$label"
        --typecode="$partition:8300"
    )
    printf '%s\t%s\t%s\t%s\t%s\n' \
        "$label" "$partition" "$start_sector" "$end_sector" "$image" >> "$output.layout.tsv"
    start_sector=$((start_sector + sectors))
    index=$((index + 1))
done

truncate -s $((start_sector * sector + mib)) "$new_output"
sgdisk "${sgdisk_args[@]}" "$new_output"
while IFS=$'\t' read -r label partition start end image; do
    [[ $label == label ]] && continue
    dd if="$image" of="$new_output" bs=1M seek=$((start / 2048)) \
        conv=notrunc,sparse status=none
done < "$output.layout.tsv"
sgdisk --verify "$new_output"
sgdisk --print "$new_output"
mv "$new_output" "$output"
