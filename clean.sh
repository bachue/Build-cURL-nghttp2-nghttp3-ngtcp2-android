#!/bin/bash
echo "Cleaning Build-cURL-nghttp2-nghttp3-ngtcp2"
rm -fr openssl/openssl nghttp2/nghttp2-1* nghttp3/nghttp3 ngtcp2/ngtcp2 curl/curl-7* \
       {nghttp2,nghttp3,ngtcp2,curl}/{arm,arm64,x86,x86_64} \
       /tmp/openssl-* /tmp/nghttp2-* /tmp/nghttp3-* /tmp/ngtcp2-* /tmp/curl-*
