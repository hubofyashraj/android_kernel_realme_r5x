#!/usr/bin/env bash
# Simple kernel build script
# Author: shygos
set -e

WORKSPACE=$(pwd)
mkdir -p ../kitchen
cd ../kitchen
KITCHEN=$(pwd)
cd $WORKSPACE

DATE=$(date '+%y%m%d-%H%M')
DEFCONFIG=straton_defconfig
KERNEL=Straton-r5x-$DATE.zip
OUTPUT=$KITCHEN/output
AK3_DIR=$KITCHEN/anykernel3
TC_DIR=$KITCHEN/toolchain

sleep 2

msg() {
	echo -e "\n|||| $1\n"
	sleep 1
}

prep_libs() {
	sudo apt update
	sudo apt upgrade -y
	sudo apt install -y binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi \
		libc++-15-dev libc++abi-15-dev device-tree-compiler bison \
		build-essential bc bison curl libssl-dev git zip python2 \
		flex cpio libncurses5-dev wget bc device-tree-compiler
	exit
}

prep_kitchen() {
	cd $KITCHEN
	if ! [ -d $AK3_DIR ]; then
		msg "Must to prepare anykernel3 dir at $AK3_DIR"
		exit
	fi
	if ! [ -d $TC_DIR ]; then
		msg "Must prepare toolchain dir at $TC_DIR"
		exit
	fi
	cd $WORKSPACE
}

regen_config() {
	msg "Regenerating defconfig"
	make $DEFCONFIG O=$OUTPUT ARCH=$ARCH SUBARCH=$SUBARCH \
		CROSS_COMPILE=$CROSS_COMPILE CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32
	cp $OUTPUT/.config $WORKSPACE/arch/$ARCH/configs/$DEFCONFIG
	git diff arch/$ARCH/configs/$DEFCONFIG
	exit
}

export_var() {
	export PATH=$TC_DIR/bin:$PATH \
		CROSS_COMPILE=aarch64-linux-gnu- \
		CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
		ARCH=arm64 \
		SUBARCH=arm64 \
		KBUILD_BUILD_USER=shygos \
		KBUILD_BUILD_HOST=straton
}

pack_kernel() {
	msg "Packing kernel into zip file"
	cd $AK3_DIR
	cp $OUTPUT/arch/$ARCH/boot/Image.gz-dtb \
		$OUTPUT/arch/$ARCH/boot/dtbo.img .
	zip -r9 "../$KERNEL" * -x .git* README.md placeholder
	cd $WORKSPACE
}

upload_kernel() {
	msg "Uploading kernel"
	cd $WORKSPACE
	git switch -C $DATE
	cp $KITCHEN/$KERNEL .
	git add -f $KERNEL
	git commit -sm $DATE
	git push origin $DATE
	git switch -
	git branch -D $DATE
}

compile_kernel() {
	CUSTOM_FLAGS="
		HOSTCC=clang
		HOSTCXX=clang++
		HOSTAR=llvm-ar
		HOSTLD=ld.lld
		CC=clang
		AR=llvm-ar
		LD=ld.lld
		NM=llvm-nm
		STRIP=llvm-strip
		OBJCOPY=llvm-objcopy
		OBJDUMP=llvm-objdump
		SIZE=llvm-size
		RANLIB=llvm-ranlib
		READELF=llvm-readelf
		LLVM=1
		LLVM_IAS=1
	"

	make $DEFCONFIG \
		O=$OUTPUT \
		ARCH=$ARCH \
		SUBARCH=$SUBARCH \
		CROSS_COMPILE=$CROSS_COMPILE \
		CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 \
		$CUSTOM_FLAGS

	COMPILE_START=$(date +"%s")

	make -j $(getconf _NPROCESSORS_ONLN) \
		O=$OUTPUT \
		ARCH=$ARCH \
		SUBARCH=$SUBARCH \
		CROSS_COMPILE=$CROSS_COMPILE \
		CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 \
		$CUSTOM_FLAGS \
		2>&1 | tee $KITCHEN/log_$DATE.log

	COMPILE_END=$(date +"%s")
	COMPILE_TIME=$((COMPILE_END - COMPILE_START))
	msg "Compilation took $((COMPILE_TIME / 60)) minute(s) and $((COMPILE_TIME % 60)) second(s)"

	if [ -f "$OUTPUT/arch/$ARCH/boot/Image.gz-dtb" ]; then
		msg "Success compiling kernel!"
	else
		msg "Failed compiling kernel!"
		exit
	fi
}

# Store the supplied arguments
echo $@ > $KITCHEN/arguments
if [[ $(grep -i clean_build $KITCHEN/arguments) ]]; then
	rm -rf $OUTPUT
fi
mkdir -p $OUTPUT
if [[ $(grep -i prep_libs $KITCHEN/arguments) ]]; then
	prep_libs
fi
export_var
if [[ $(grep -i regen_config $KITCHEN/arguments) ]]; then
	regen_config
fi
prep_kitchen
compile_kernel
pack_kernel
if [[ $(grep -i upload_kernel $KITCHEN/arguments) ]]; then
	upload_kernel
fi

exit
