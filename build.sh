#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Build the imx boot container and U-Boot
echo "#########################"
echo "#   build-imx-boot.sh   #"
echo "#########################"
time ./scripts/build-imx-boot.sh
echo "Finished build-imx-boot.sh with no erros!"

# Build the Linux kernel and Device Tree Blobs
echo "#########################"
echo "#    build-kernel.sh    #"
echo "#########################"
time ./scripts/build-kernel.sh
echo "Finished build-kernel.sh with no erros!"

echo "#########################"
echo "#    build-rootfs.sh    #"
echo "#########################"
# Build the root file system
time ./scripts/build-rootfs.sh
echo "Finished build-rootfs.sh with no erros!"

echo "#########################"
echo "#    build-image.sh     #"
echo "#########################"
# Build the Ubuntu preinstalled images
time ./scripts/build-image.sh
echo "Finished build-image.sh with no erros!"
