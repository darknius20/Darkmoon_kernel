#!/bin/bash 
rm -rf out
rm -rf AnyKernel
echo "Cloning dependencies"
sudo apt update
sudo apt upgrade
sudo apt install --no-install-recommends -y bc bison curl ccache ca-certificates flex gcc git glibc-doc jq libxml2 libtinfo5 libc6-dev libssl-dev libstdc++6 make openssl python rclone ssh tar tzdata wget zip
git clone --depth=1 https://github.com/kdrag0n/proton-clang clang
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
git clone https://github.com/dragonroad99/AnyKernel3  --depth=1 AnyKernel

echo "Done"
KERNEL_DIR=$(pwd)
IMAGE="${KERNEL_DIR}/out/arch/arm64/boot/Image"
TANGGAL=$(date +"%Y%m%d-%H%M")
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
export ARCH=arm64
export KBUILD_BUILD_USER=Darknius
export KBUILD_BUILD_HOST=Gitpod

make O=out ARCH=arm64 vendor/citrus-perf_defconfig

# Compile plox
compile() {
    make -j$(nproc) O=out \
                    ARCH=arm64 \
                    CC=clang \
                    CLANG_TRIPLE=aarch64-linux-gnu- \
                    CROSS_COMPILE=aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=arm-linux-androideabi- $1 $2 $3 \
                    LLVM=1
}


module() {
[ -d "modules" ] && rm -rf modules || mkdir -p modules

compile \
INSTALL_MOD_PATH=../modules \
INSTALL_MOD_STRIP=1 \
modules_install
}

# Zipping
zipping() {
    cd AnyKernel || exit 1
    cp ../out/arch/arm64/boot/Image .
    cp ../out/arch/arm64/boot/dtb.img .
    cp ../out/arch/arm64/boot/dtbo.img .
    zip -r9 DarkLegacy-citrus-Q-R1-${TANGGAL}.zip *
    cd ..
}

# Upload
upload() {
    cd AnyKernel && curl -sL https://git.io/file-transfer | sh && ./transfer wet *.zip
    cd ..
}

compile
module
zipping
upload