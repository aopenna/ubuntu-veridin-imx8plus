#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if test "$#" -ne 1; then
    echo "Usage: $0 filename.img.xz"
    exit 1
fi

img="$(readlink -f "$1")"
if [ ! -f "${img}" ]; then
    echo "Error: $1 does not exist"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

# Ensure the imx bootloader exists
bootloader="imx-mkimage/iMX8QM/imx-boot"
if [ ! -f "${bootloader}" ] ; then
    echo "Error: could not find the imx bootloader, please run build-imx-boot.sh"
    exit 1
fi

# Ensure xz archive
echo "Decompressing image"
filename="$(basename "${img}")"
if [ "${filename##*.}" == "xz" ]; then
    xz -dc -T0 "${img}" > "${filename%.*}"
    img="$(readlink -f "${filename%.*}")"
fi

# Ensure img file
echo "Testing image"
filename="$(basename "${img}")"
if [ "${filename##*.}" != "img" ]; then
    echo "Error: ${filename} must be an disk image file"
    exit 1
fi

# Download the Universal Update Utility (uuu)
if [ ! -f uuu/uuu ]; then
    echo "Downloading uuu 1.5.165"
    wget https://github.com/NXPmicro/mfgtools/releases/download/uuu_1.5.165/uuu -P uuu
    chmod +x uuu/uuu
fi

# Script to flash bootloader and os image
cat > uuu/flash.uuu << EOF
uuu_version 1.5.165

# Toradex configs
CFG: FB: -vid 0x0525 -pid 0x4000
CFG: FB: -vid 0x0525 -pid 0x4025
CFG: FB: -vid 0x0525 -pid 0x402F
CFG: FB: -vid 0x0525 -pid 0x4030
CFG: FB: -vid 0x0525 -pid 0x4031
CFG: FB: -vid 0x1b67 -pid 0x4025

# Load bootloader image into RAM
SDPS: boot -f "${bootloader}"

# Setup uboot environment for flashing the emmc
FB: ucmd setenv fastboot_dev mmc
FB: ucmd setenv mmcdev 0
FB: ucmd mmc dev 0

# Flash the bootloader to the emmc boot partition
FB: flash bootloader "${bootloader}"
FB: ucmd mmc partconf 0 0 1 0

# Flash the os image to the emmc
FB: flash -raw2sparse all "${img}"

# Save the default environment variables 
FB: ucmd env default -a
FB: ucmd saveenv
FB: done
EOF

./uuu/uuu -b uuu/flash.uuu
