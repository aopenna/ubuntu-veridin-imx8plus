#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build


# Download and extract the IMX Firmware
if [ ! -d firmware-imx-8.10.1 ]; then
    wget -nc https://www.nxp.com/lgfiles/NMG/MAD/YOCTO/firmware-imx-8.10.1.bin
    chmod +x firmware-imx-8.10.1.bin
    ./firmware-imx-8.10.1.bin --auto-accept --force
    cp firmware-imx-8.10.1/firmware/ddr/synopsys/lpddr4*_202006.bin ./
    rm -f firmware-imx-8.10.1.bin
fi

# Download and build the ARM Trusted Firmware (ATF)
if [ ! -d trusted-firmware-a ]; then
    git clone https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git
    #git clone --depth=1 --progress -b toradex_imx_5.4.70_2.3.0 git://git.toradex.com/imx-atf.git 
fi
cd trusted-firmware-a
#cd imx-atf
make PLAT=imx8mp CROSS_COMPILE=aarch64-linux-gnu- IMX_BOOT_UART_BASE=0x30880000 bl31
cd ..

# Download and build u-boot
if [ ! -d u-boot-toradex ]; then
    #git clone --depth=1 --progress -b toradex_imx_lf_v2022.04 git://git.toradex.com/u-boot-toradex.git
    git clone --depth=1 --progress -b toradex_imx_v2020.04_5.4.70_2.3.0 git://git.toradex.com/u-boot-toradex.git
fi
cd u-boot-toradex
if git apply --check ../../patches/u-boot-toradex/0001-usb-first-boot-target.patch > /dev/null 2>&1; then
    git apply ../../patches/u-boot-toradex/0001-usb-first-boot-target.patch
fi
cp ../trusted-firmware-a/build/imx8mp/release/bl31.bin bl31.bin
cp ../firmware-imx-8.10.1/firmware/ddr/synopsys/lpddr4*_202006.bin ./
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- mrproper
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- verdin-imx8mp_defconfig
make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- -j "$(nproc)"
cd ..

# Download and build the boot container
if [ ! -d imx-mkimage ]; then
    git clone --depth=1 --progress -b lf-5.15.32_2.0.0 https://github.com/nxp-imx/imx-mkimage.git
fi
cd imx-mkimage
cp ../u-boot-toradex/u-boot.bin iMX8M/u-boot.bin
cp ../firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_1d_dmem_202006.bin iMX8M
cp ../firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_2d_dmem_202006.bin iMX8M
cp ../firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_1d_imem_202006.bin iMX8M
cp ../firmware-imx-*/firmware/ddr/synopsys/lpddr4_pmu_train_2d_imem_202006.bin iMX8M
cp ../trusted-firmware-a/build/imx8mp/release/bl31.bin iMX8M
cp ../u-boot-toradex/spl/u-boot-spl.bin iMX8M
cp ../u-boot-toradex/u-boot-nodtb.bin iMX8M
cp ../u-boot-toradex/arch/arm/dts/imx8mp-verdin.dtb iMX8M/fsl-imx8mp-evk.dtb
cp ../u-boot-toradex/tools/mkimage iMX8M/mkimage_uboot

make SOC=iMX8MP CROSS_COMPILE=aarch64-linux-gnu- DCD_BOARD=imx8mp_evk flash_evk_emmc_fastboot
cp iMX8M/flash.bin iMX8M/imx-boot
