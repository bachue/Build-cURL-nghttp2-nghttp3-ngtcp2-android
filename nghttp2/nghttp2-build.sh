#!/bin/bash
# This script downloads and builds the Android nghttp2 library
#
# Credits:
#
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-nghttp3-ngtcp2-android
# NGHTTP2 - https://github.com/nghttp2/nghttp2
#

# > nghttp2 is an implementation of HTTP/2 and its header
# > compression algorithm HPACK in C

set -e

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${green}\033[1m"
subbold="\033[0m${green}"
archbold="\033[0m${yellow}\033[1m"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

# set trap to help debug build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/nghttp2*.log${alertdim}"; tail -n 3 /tmp/nghttp2*.log' INT TERM EXIT

NGHTTP2_VERNUM="1.41.0"
NDK_VERSION="20b"
ANDROID_EABI_VERSION="4.9"
ANDROID_API_VERSION="21"

usage ()
{
    echo
    echo -e "${bold}Usage:${normal}"
    echo
    echo -e "  ${subbold}$0${normal} [-v ${dim}<nghttp2 version>${normal}] [-a ${dim}<Android API version>${normal}] [-n ${dim}<NDK version>${normal}] [-e ${dim}<EABI version>${normal}] [-x] [-h]"
    echo
    echo "         -v   version of nghttp2 (default $NGHTTP2_VERNUM)"
    echo "         -n   NDK version (default $NDK_VERSION)"
    echo "         -a   Android API version (default $ANDROID_API_VERSION)"
    echo "         -e   EABI version (default $ANDROID_EABI_VERSION)"
    echo "         -x   disable color output"
    echo "         -h   show usage"
    echo
    trap - INT TERM EXIT
    exit 127
}

while getopts "v:n:a:e:xh\?" o; do
    case "${o}" in
        v)
            NGHTTP2_VERNUM="${OPTARG}"
            ;;
        n)
            NDK_VERSION="${OPTARG}"
            ;;
        a)
            ANDROID_API_VERSION="${OPTARG}"
            ;;
        e)
            ANDROID_EABI_VERSION="${OPTARG}"
            ;;
        x)
            bold=""
            subbold=""
            normal=""
            dim=""
            alert=""
            alertdim=""
            archbold=""
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ANDROID_NDK_HOME must be set" >&2
    exit 1
fi

NGHTTP2_VERSION="nghttp2-${NGHTTP2_VERNUM}"
NGHTTP2="${PWD}/../nghttp2"

checkTool()
{
    TOOL=$1
    PKG=$2

    if (type "$1" > /dev/null) ; then
        echo "  $2 already installed"
    else
        echo -e "${alertdim}** WARNING: $2 not installed... attempting to install.${dim}"

        if ! type "apt" > /dev/null; then
            echo -e "${alert}** FATAL ERROR: apt not installed - unable to install $2 - exiting.${normal}"
            exit
        else
            echo "  apt installed - using to install $2"
            apt install -yqq "$2"
        fi

        # Check to see if installation worked
        if (type "$1" > /dev/null) ; then
            echo "  SUCCESS: $2 installed"
        else
            echo -e "${alert}** FATAL ERROR: $2 failed to install - exiting.${normal}"
            exit
        fi
    fi
}

checkTool pkg-config pkg-config

buildAndroid() {
    ARCH=$1
    HOST=$2
    TOOLCHAIN_PREFIX=$3
    TOOLCHAIN=$4
    PREFIX="${ANDROID_NDK_HOME}/platforms/android-${ANDROID_API_VERSION}/arch-${ARCH}"/usr

    echo -e "${subbold}Building ${NGHTTP2_VERSION} for ${archbold}${ARCH}${dim}"

    pushd . > /dev/null
    cd "${NGHTTP2_VERSION}"

    ./configure \
        --disable-shared \
        --disable-app \
        --disable-threads \
        --enable-lib-only \
        --host="$HOST" \
        --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
        --without-libxml2 \
        --disable-python-bindings \
        --disable-examples \
        --prefix="${NGHTTP2}/${ARCH}" \
        CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_VERSION}-clang" \
        CXX="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_VERSION}-clang++" \
        AR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-ar" \
        AS="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-as" \
        LD="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-ld" \
        NM="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-nm" \
        RANLIB="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-ranlib" \
        STRIP="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN}-strip" \
        CFLAGS="-arch ${ARCH} -pipe -Os" \
        CPPFLAGS="-fPIE -I$PREFIX/include" \
        PKG_CONFIG_LIBDIR="${ANDROID_NDK_HOME}/prebuilt/linux-x86_64/lib/pkgconfig" \
        LDFLAGS="-arch ${ARCH} -fPIE -pie -L$PREFIX/lib" &> "/tmp/${NGHTTP2_VERSION}-${ARCH}.log"
    make -j8 >> "/tmp/${NGHTTP2_VERSION}-${ARCH}.log" 2>&1
    make install >> "/tmp/${NGHTTP2_VERSION}-${ARCH}.log" 2>&1
    make clean >> "/tmp/${NGHTTP2_VERSION}-${ARCH}.log" 2>&1
    popd > /dev/null
}

echo -e "${bold}Cleaning up${dim}"
rm -rf nghttp2 /tmp/${NGHTTP2_VERSION}-*

if [ ! -e ${NGHTTP2_VERSION}.tar.gz ]; then
    echo "Downloading ${NGHTTP2_VERSION}.tar.gz"
    curl -LO https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERNUM}/${NGHTTP2_VERSION}.tar.gz
else
    echo "Using ${NGHTTP2_VERSION}.tar.gz"
fi

echo "Unpacking nghttp2"
tar xfz "${NGHTTP2_VERSION}.tar.gz"

echo "** Building ${NGHTTP2_VERSION} **"
buildAndroid x86 i686-pc-linux-gnu i686-linux-android i686-linux-android
buildAndroid x86_64 x86_64-pc-linux-gnu x86_64-linux-android x86_64-linux-android
buildAndroid arm arm-linux-androideabi armv7a-linux-androideabi arm-linux-androideabi
buildAndroid arm64 aarch64-linux-android aarch64-linux-android aarch64-linux-android

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
