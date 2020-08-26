#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
# Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
#

sudo apt update
sudo apt upgrade -y
sudo apt install --no-install-recommends -y bc bison curl ccache ca-certificates flex gcc git glibc-doc jq libxml2 libtinfo5 libc6-dev libssl-dev libstdc++6 make openssl python rclone ssh tar tzdata wget zip

# Persiapan
NAMA_PERANGKAT="Poco M3"
KODE_PERANGKAT=citrus
DEFCONFIG_PERANGKAT=vendor/citrus-perf_defconfig
TOKEN_BOT_TELEGRAM="1322538934:AAGf6p-NvdOCXqowaX5aFfhuQPKTo4pni78"
ID_CHAT_TELEGRAM="-683823277"
NAMA_PEMBANGUN="Darknius"
HOST_PEMBANGUN="Gitpod"


# Pilih "clang" atau "gcc"
ALAT=clang

	if [ $ALAT = "clang" ]
	then
		git clone --depth=1 -b master https://github.com/kdrag0n/proton-clang.git  clang
		git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
	fi

	if [ $ALAT = "gcc" ]
	then
		git clone --depth=1 -b sc-v13.x https://github.com/OhMyVenyx/aarch64-elf-gcc.git gcc
		git clone --depth=1 -b sc-v13.x https://github.com/OhMyVenyx/arm-eabi-gcc.git gcc32
	fi

LOKASI_PEMBANGUNAN_KERNEL=$(pwd)
VERSI_KERNEL=$(make kernelversion)
LOG_TERAKHIR_KOMIT=$(git log --pretty=format:'%s' -1)
export KBUILD_BUILD_USER=$NAMA_PEMBANGUN
export KBUILD_BUILD_HOST=$HOST_PEMBANGUN
NAMA_KERNEL="$(cat arch/arm64/configs/vendor/${DEFCONFIG_PERANGKAT} | grep "CONFIG_LOCALVERSION\=" | sed -r 's/.*"(.+)".*/\1/' | sed 's/^.//')"
FILE_KERNEL=$(pwd)/out/arch/arm64/boot/Image
TANGGAL=$(date +%y%m%d-%H%M)
MULAI=$(date +"%s")

	if [ $ALAT = "clang" ]
	then
			ALAT_PEMBANGUNAN_KERNEL=$(${LOKASI_PEMBANGUNAN_KERNEL}/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
			PATH="${LOKASI_PEMBANGUNAN_KERNEL}/clang/bin/:${LOKASI_PEMBANGUNAN_KERNEL}/gcc/bin:${LOKASI_PEMBANGUNAN_KERNEL}/gcc32/bin:$PATH"
	elif [ $ALAT = "gcc" ]
	then
			ALAT_PEMBANGUNAN_KERNEL=$(${LOKASI_PEMBANGUNAN_KERNEL}/gcc/bin/aarch64-elf-gcc --version | head -n 1)
			PATH="${LOKASI_PEMBANGUNAN_KERNEL}/gcc/bin/:${LOKASI_PEMBANGUNAN_KERNEL}/gcc32/bin/:/usr/bin:$PATH"
	fi

# AnyKernel3
git clone --depth=1 https://github.com/dragonroad99/AnyKernel3

# Pesan telegram
export URL_PESAN_BOT="https://api.telegram.org/bot$TOKEN_BOT_TELEGRAM/sendMessage"

tg_post_msg() {
  curl -s -X POST "$URL_PESAN_BOT" -d chat_id="$ID_CHAT_TELEGRAM" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Membangun kernel
function membangun(){
	if [ $ALAT = "clang" ]
	then
		MAKE+=(
			CC=clang \
			AR=llvm-ar \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
			NM=llvm-nm \
			OBJCOPY=llvm-objcopy \
			CROSS_COMPILE=aarch64-linux-gnu- \
            CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
			LD=ld.lld
		)
	elif [ $ALAT = "gcc" ]
	then
		MAKE+=(
			AR=aarch64-elf-ar \
			OBJDUMP=aarch64-elf-objdump \
			STRIP=aarch64-elf-strip \
			NM=aarch64-elf-nm \
			OBJCOPY=aarch64-elf-objcopy \
                        CROSS_COMPILE=aarch64-elf- \
			CROSS_COMPILE_ARM32=arm-eabi-
		)
	fi
		make -j$(nproc --all) O=out ${DEFCONFIG_PERANGKAT}
		make -j$(nproc --all) O=out \
				"${MAKE[@]}" 2>&1 | tee build.log

   if ! [ -a "$FILE_KERNEL" ]; then
	rusak
	exit 1
   fi
	cp $FILE_KERNEL AnyKernel3/
}

# Kirim flashable kernel ke channel
function kirim() {
    cd AnyKernel3
    ARSIP=$(echo *.zip)
    curl -F document=@$ARSIP "https://api.telegram.org/bot$TOKEN_BOT_TELEGRAM/sendDocument" \
        -F chat_id="$ID_CHAT_TELEGRAM" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="🐧 Linux version : <code>${VERSI_KERNEL}</code>
📱 For device : <b>${NAMA_PERANGKAT} ($KODE_PERANGKAT)</b>
🍕 Last commit : <b>${LOG_TERAKHIR_KOMIT}</b>
📌 MD5 Checksum : <code>$(md5sum ${ARSIP} | cut -d' ' -f1)</code>
🛠 Compiler : <b>${ALAT_PEMBANGUNAN_KERNEL}</b>

✅ Build took : <code>$(($DIFF / 60))</code> minute(s) and <code>$(($DIFF % 60))</code> second(s)."
}

# Kirim log ke channel jika ada error/rusak
function rusak() {
    LOG=build.log
    curl -F document=@$LOG "https://api.telegram.org/bot$TOKEN_BOT_TELEGRAM/sendDocument" \
        -F chat_id="$ID_CHAT_TELEGRAM" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Ada kesalahan, mohon cek log"
    exit 1
}

# Kompres ke zip
function kompress() {
    cd AnyKernel3
    zip -r9 DarkMoon-${TANGGAL}-citrus.zip .
    cd ..
}

# Bersih bersih sisa
function bersihkan() {
    rm -rf ${LOKASI_PEMBANGUNAN_KERNEL}/AnyKernel3/Image* ${LOKASI_PEMBANGUNAN_KERNEL}/AnyKernel3/*.zip ${LOKASI_PEMBANGUNAN_KERNEL}/out ${LOKASI_PEMBANGUNAN_KERNEL}/build.log
}

membangun
kompress
SELESAI=$(date +"%s")
DIFF=$(($SELESAI - $MULAI))
kirim
bersihkan
