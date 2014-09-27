#!/bin/bash
TMP_DIR=/tmp/protobuf_$$

#curl -O https://raw.githubusercontent.com/sinofool/build-protobuf-ios/master/patch-arm64.patch
#patch src/google/protobuf/stubs/platform_macros.h < patch-arm64.patch

###################################################
# Build i386 version first, 
# Because arm needs it binary.
###################################################
CFLAGS=-m32 CPPFLAGS=-m32 CXXFLAGS=-m32 LDFLAGS=-m32 ./configure --prefix=${TMP_DIR}/i386 \
        --disable-shared \
        --enable-static || exit 1
make clean || exit 2
make -j8 || exit 3
make install || exit 4

###################################################
# Build x86_64 version, 
###################################################
CFLAGS=-m64 CPPFLAGS=-m64 CXXFLAGS=-m64 LDFLAGS=-m64 ./configure --prefix=${TMP_DIR}/x86_64 \
        --disable-shared \
        --enable-static || exit 1
make clean || exit 2
make -j8 || exit 3
make install || exit 4

###################################################
# iOS SDK location. 
###################################################

SDKROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.0.sdk
DEVROOT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/
export CC=${DEVROOT}/usr/bin/clang
export CXX=${DEVROOT}/usr/bin/clang++

function build_for()
{
BUILD_FOR=$1
HOST=$2
###################################################
# Build $1 version, 
###################################################
export ARCH_TARGET="-arch ${BUILD_FOR} -isysroot $SDKROOT"
export CFLAGS="${ARCH_TARGET} -g -O0"
export CXXFLAGS="$CFLAGS -std=c++11 -stdlib=libc++"
export LDFLAGS="${ARCH_TARGET} -stdlib=libc++ -lc++ -lc++abi -Wl,-syslibroot $SDKROOT"
./configure --prefix=$TMP_DIR/${BUILD_FOR} \
        --with-protoc=${TMP_DIR}/i386/bin/protoc \
        --disable-shared \
        --enable-static \
        --host=${HOST} || exit 1
make clean || exit 2
make -j8 || exit 3
make install || exit 4
}

build_for armv7 armv7-apple-darwin
build_for armv7s armv7s-apple-darwin
build_for arm64 arm-apple-darwin

###################################################
# Packing
###################################################
DIST_DIR=$HOME/Desktop/protobuf_dist
rm -rf ${DIST_DIR}
mkdir -p ${DIST_DIR}
mkdir ${DIST_DIR}/{bin,lib}
cp -r ${TMP_DIR}/armv7/include ${DIST_DIR}/
cp ${TMP_DIR}/i386/bin/protoc ${DIST_DIR}/bin/
${DEVROOT}/usr/bin/lipo \
	-arch i386 ${TMP_DIR}/i386/lib/libprotobuf.a \
	-arch x86_64 ${TMP_DIR}/x86_64/lib/libprotobuf.a \
	-arch armv7 ${TMP_DIR}/armv7/lib/libprotobuf.a \
	-arch armv7s ${TMP_DIR}/armv7s/lib/libprotobuf.a \
	-arch arm64 ${TMP_DIR}/arm64/lib/libprotobuf.a \
	-output ${DIST_DIR}/lib/libprotobuf.a -create

