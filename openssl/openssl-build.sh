#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS openSSL libraries with Bitcode enabled

# Credits:
#
# Gustavo Genovese, @gcesarmza
#   https://github.com/gcesarmza/curl-android-ios/blob/master/curl-compile-scripts/build_Android.sh
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-nghttp3-ngtcp2-android

# Custom build options
CUSTOMCONFIG="enable-ssl-trace enable-tls1_3"

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
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/openssl*.log${alertdim}"; tail -3 /tmp/openssl*.log' INT TERM EXIT
