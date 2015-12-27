#!/bin/bash
TMP_DIR=/tmp/protobuf_$$

#curl -O https://raw.githubusercontent.com/sinofool/build-protobuf-ios/master/patch-arm64.patch
#patch src/google/protobuf/stubs/platform_macros.h < patch-arm64.patch

###################################################
# Build OSX version first, 
###################################################
./configure --prefix=${TMP_DIR}/osx \
        --disable-shared \
        --enable-static || exit 1
make clean || exit 2
make -j8 || exit 3
make install || exit 4

###################################################
# iOS SDK location. 
###################################################

IOS_SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk
SIM_SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk
DEVROOT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/
export CC=${DEVROOT}/usr/bin/clang
export CXX=${DEVROOT}/usr/bin/clang++
export PATH=${DEVROOT}/usr/bin:$PATH
export MACOSX_DEPLOYMENT_TARGET=10.11

function build_for()
{
BUILD_FOR=$1
HOST=$2
if [ "$BUILD_FOR" == "x86_64" ] || [ "$BUILD_FOR" == "i386" ]
then
SDKROOT=$SIM_SDKROOT
else
SDKROOT=$IOS_SDKROOT
fi

###################################################
# Build $1 version, 
###################################################
export ARCH_TARGET="-arch ${BUILD_FOR} -isysroot $SDKROOT"
export CFLAGS="${ARCH_TARGET} -g -O3 -fembed-bitcode -miphoneos-version-min=7.0"
export CXXFLAGS="$CFLAGS -std=c++11 -stdlib=libc++"
export LDFLAGS="${ARCH_TARGET} -stdlib=libc++ -lc++ -lc++abi"
./configure --prefix=$TMP_DIR/${BUILD_FOR} \
        --with-sysroot=$SDKROOT \
        --with-protoc=${TMP_DIR}/osx/bin/protoc \
        --disable-shared \
        --enable-static \
        --host=${HOST} || exit 1
make clean || exit 2
make -j8 || exit 3
make install || exit 4
}

build_for i386 i386-apple-darwin
build_for x86_64 x86_64-apple-darwin
build_for armv7 armv7-apple-darwin
build_for armv7s armv7s-apple-darwin
build_for arm64 arm-apple-darwin

###################################################
# Packing
###################################################
DFT_DIST_DIR=$HOME/Desktop/protobuf-dist
DIST_DIR=${DIST_DIR:-$DFT_DIST_DIR}
mkdir -p ${DIST_DIR}/{bin,lib}
cp -r ${TMP_DIR}/armv7s/include ${DIST_DIR}/
cp ${TMP_DIR}/osx/bin/protoc ${DIST_DIR}/bin/
${DEVROOT}/usr/bin/lipo \
	-arch i386 ${TMP_DIR}/i386/lib/libprotobuf.a \
	-arch x86_64 ${TMP_DIR}/x86_64/lib/libprotobuf.a \
	-arch armv7 ${TMP_DIR}/armv7/lib/libprotobuf.a \
	-arch armv7s ${TMP_DIR}/armv7s/lib/libprotobuf.a \
	-arch arm64 ${TMP_DIR}/arm64/lib/libprotobuf.a \
	-output ${DIST_DIR}/lib/libprotobuf.a -create

