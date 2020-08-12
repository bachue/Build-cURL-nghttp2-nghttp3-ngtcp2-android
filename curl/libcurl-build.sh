#!/bin/bash

# This script downloads and builds the Android libcurl library

# Credits:
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-nghttp3-ngtcp2-android

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

# set trap to help debug any build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/curl*.log${alertdim}"; tail -n 3 /tmp/curl*.log' INT TERM EXIT

CURL_VERSION="curl-7.71.1"
NDK_VERSION="20b"
ANDROID_EABI_VERSION="4.9"
ANDROID_API_VERSION="21"
nohttp2="0"
nohttp3="0"

usage ()
{
    echo
    echo -e "${bold}Usage:${normal}"
    echo
    echo -e "  ${subbold}$0${normal} [-v ${dim}<curl version>${normal}] [-a ${dim}<Android API version>${normal}] [-n ${dim}<NDK version>${normal}] [-e ${dim}<EABI version>${normal}] [-x] [-2] [-3] [-h]"
    echo
    echo "         -v   version of curl (default $CURL_VERSION)"
    echo "         -n   NDK version (default $NDK_VERSION)"
    echo "         -a   Android API version (default $ANDROID_API_VERSION)"
    echo "         -e   EABI version (default $ANDROID_EABI_VERSION)"
    echo "         -2   compile with nghttp2"
    echo "         -3   compile with ngtcp2"
    echo "         -x   disable color output"
    echo "         -h   show usage"
    echo
    trap - INT TERM EXIT
    exit 127
}

while getopts "v:n:a:e:23xh\?" o; do
    case "${o}" in
        v)
            CURL_VERSION="curl-${OPTARG}"
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
        2)
            nohttp2="1"
            ;;
        3)
            nohttp3="1"
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

# HTTP2 support
if [ $nohttp2 == "1" ]; then
    # nghttp2 will be in ../nghttp2/{Platform}/{arch}
    NGHTTP2="${PWD}/../nghttp2"
fi

if [ $nohttp2 == "1" ]; then
    echo "Building with HTTP2 Support (nghttp2)"
else
    echo "Building without HTTP2 Support (nghttp2)"
    NGHTTP2CFG=""
    NGHTTP2LIB=""
fi

# HTTP3 support
if [ $nohttp3 == "1" ]; then
    NGHTTP3="${PWD}/../nghttp3"
    NGTCP2="${PWD}/../ngtcp2"
    echo "Building with HTTP3 Support (ngtcp2)"
else
    echo "Building without HTTP3 Support (ngtcp2)"
    NGHTTP3CFG=""
    NGHTTP3LIB=""
    NGTCP2CFG=""
    NGTCP2LIB=""
fi

CURL="${PWD}/../curl"

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

checkTool autoreconf autoconf
checkTool aclocal automake
checkTool libtool libtool
checkTool git git

buildAndroid() {
    ARCH=$1
    HOST=$2
    TOOLCHAIN_PREFIX=$3
    TOOLCHAIN=$4
    PREFIX="${ANDROID_NDK_HOME}/platforms/android-${ANDROID_API_VERSION}/arch-${ARCH}/usr"

    echo -e "${subbold}Building libcurl for ${archbold}${ARCH}${dim}"

    pushd . > /dev/null
    cd "${CURL_VERSION}"
    autoreconf -i

    if [ $nohttp2 == "1" ]; then
        NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/${ARCH}"
        NGHTTP2LIB="-L${NGHTTP2}/${ARCH}/lib"
    fi
    if [ $nohttp3 == "1" ]; then
        NGHTTP3CFG="--with-nghttp3=${NGHTTP3}/${ARCH}"
        NGHTTP3LIB="-L${NGHTTP3}/${ARCH}/lib"
        NGTCP2CFG="--with-ngtcp2=${NGTCP2}/${ARCH}"
        NGTCP2LIB="-L${NGTCP2}/${ARCH}/lib"
    fi

    ./configure \
        --enable-optimize \
        --enable-ipv6 \
        --with-pic \
        --with-random=/dev/urandom \
        --with-ssl=/tmp/openssl-${ARCH} \
        ${NGHTTP2CFG} ${NGHTTP3CFG} ${NGTCP2CFG} \
        --host="$HOST" \
        --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
        --prefix="${CURL}/${ARCH}" \
        --enable-alt-svc \
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
        PKG_CONFIG_LIBDIR="${ANDROID_NDK_HOME}/prebuilt/linux-x86_64/lib/pkgconfig:/tmp/openssl-${ARCH}/lib/pkgconfig:${PWD}/../nghttp3/${ARCH}/lib/pkgconfig:${PWD}/../ngtcp2/${ARCH}/lib/pkgconfig" \
        LDFLAGS="-arch ${ARCH} -fPIE -pie -L$PREFIX/lib -Wl,-rpath,/tmp/openssl-${ARCH}/lib" &> "/tmp/curl-${ARCH}.log"

    make -j8 >> "/tmp/curl-${ARCH}.log" 2>&1
    make install >> "/tmp/curl-${ARCH}.log" 2>&1
    make clean >> "/tmp/curl-${ARCH}.log" 2>&1
    popd > /dev/null
}

echo -e "${bold}Cleaning up${dim}"
rm -rf "/tmp/${CURL_VERSION}-*" "${CURL_VERSION}"

if [ ! -f "${CURL_VERSION}.zip" ]; then
    echo "Downloading ${CURL_VERSION}.zip"
    # curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
    wget -O ${CURL_VERSION}.zip https://github.com/curl/curl/archive/master.zip
else
    echo "Using ${CURL_VERSION}.zip"
fi

rm -rf "${CURL_VERSION}"
echo "Unpacking curl"
unzip -qq "${CURL_VERSION}.zip"
mv curl-master "$CURL_VERSION"

echo "** Building libcurl **"
buildAndroid x86_64 x86_64-pc-linux-gnu x86_64-linux-android x86_64-linux-android
buildAndroid arm arm-linux-androideabi armv7a-linux-androideabi arm-linux-androideabi
buildAndroid arm64 aarch64-linux-android aarch64-linux-android aarch64-linux-android

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
