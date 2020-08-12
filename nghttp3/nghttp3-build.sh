#!/bin/bash
# This script downloads and builds the Android nghttp3 library
#
# Credits:
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-OpenSSL-cURL
#
# NGHTTP3 - https://github.com/ngtcp2/nghttp3
#

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
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/nghttp3*.log${alertdim}"; tail -n 3 /tmp/nghttp3*.log' INT TERM EXIT

NDK_VERSION="20b"
ANDROID_EABI_VERSION="4.9"
ANDROID_API_VERSION="21"

usage ()
{
    echo
    echo -e "${bold}Usage:${normal}"
    echo
    echo -e "  ${subbold}$0${normal} [-a ${dim}<Android API version>${normal}] [-n ${dim}<NDK version>${normal}] [-e ${dim}<EABI version>${normal}] [-x] [-h]"
    echo
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

NGHTTP3="${PWD}/../nghttp3"

checkTool()
{
    TOOL=$1
    PKG=$2

    if (type "$1" > /dev/null) ; then
        echo "  $2 already installed"
    else
        echo -e "${alertdim}** WARNING: $2 not installed... attempting to install.${dim}"

        # Check to see if Brew is installed
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

checkTool autoreconf autoconf
checkTool aclocal automake
checkTool aclocal automake
checkTool libtool libtool
checkTool git git

buildAndroid() {
    ARCH=$1
    HOST=$2
    TOOLCHAIN_PREFIX=$3
    PREFIX="${ANDROID_NDK_HOME}/platforms/android-${ANDROID_API_VERSION}/arch-${ARCH}"/usr

    echo -e "${subbold}Building nghttp3 for ${archbold}${ARCH}${dim}"

    pushd . > /dev/null
    cd nghttp3
    autoreconf -i

    ./configure \
        --disable-shared \
        --enable-lib-only \
        --host="$HOST" \
        --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
        --prefix="${NGHTTP3}/${ARCH}" \
        CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_VERSION}-clang" \
        CXX="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/${TOOLCHAIN_PREFIX}${ANDROID_API_VERSION}-clang++" \
        CPPFLAGS="-fPIE -I$PREFIX/include" \
        PKG_CONFIG_LIBDIR="${ANDROID_NDK_HOME}/prebuilt/linux-x86_64/lib/pkgconfig" \
        LDFLAGS="-fPIE -pie -L$PREFIX/lib" &> "/tmp/nghttp3-${ARCH}.log"
    LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "config.h"

    make -j8 >> "/tmp/nghttp3-${ARCH}.log" 2>&1
    make install >> "/tmp/nghttp3-${ARCH}.log" 2>&1
    make clean >> "/tmp/nghttp3-${ARCH}.log" 2>&1
    popd > /dev/null
}

echo -e "${bold}Cleaning up${dim}"
rm -rf nghttp3

echo "Cloning nghttp3"
git clone --depth 1 https://github.com/ngtcp2/nghttp3.git

echo "** Building nghttp3 **"
buildAndroid x86_64 x86_64 x86_64-linux-android
buildAndroid arm arm-linux-androideabi armv7a-linux-androideabi
buildAndroid arm64 aarch64-linux-android aarch64-linux-android

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
