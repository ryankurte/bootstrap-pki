#!/bin/bash
# A script to bootstrap PKI using a pair of Yubikeys
# Resources:
# - https://developers.yubico.com/yubico-piv-tool/
# - https://developers.yubico.com/PIV/Guides/Certificate_authority.html
# - https://github.com/OpenSC/OpenSC/wiki/SmartCardHSM

# Company Name ie. Foo NZ Ltd.
CA_CN="foo ltd."
# Organisational Unit ie. Research and Development
CA_OU="R&D"
# Organisation name ie. foo.nz
CA_ORG="foobar.com"

KEYLEN=2048 # Key length
SLOT=9c     # Yubikey Certification slot
DIR=work

CONFIG="\'/CN=${CA_CN}/OU=${CA_OU}/O=${CA_ORG}/\'"

set -e

echo "Generating CA config files"
sed "s/URL/${CA_ORG}/g;s/COMMON_NAME/${CA_CN}/g;s/ROOT/ROOT A/g" ca.conf.in > $DIR/ca1.conf
sed "s/URL/${CA_ORG}/g;s/COMMON_NAME/${CA_CN}/g;s/ROOT/ROOT B/g" ca.conf.in > $DIR/ca2.conf

echo "Generating Keys"
# TODO: generate keys on device, should be able to sign then swap certs without changing keys
openssl genrsa -out $DIR/ca1.key ${KEYLEN}
openssl genrsa -out $DIR/ca2.key ${KEYLEN}

echo "Self signing root certificates"
openssl req -x509 -new -nodes -key $DIR/ca1.key -sha256 -days 36500 -out $DIR/ca1.crt -config $DIR/ca1.conf
openssl req -x509 -new -nodes -key $DIR/ca2.key -sha256 -days 36500 -out $DIR/ca2.crt -config $DIR/ca2.conf

echo "Generate cross signing CSRs"
openssl req -new -out $DIR/ca1.csr -key $DIR/ca1.key -config $DIR/ca1.conf
openssl req -new -out $DIR/ca2.csr -key $DIR/ca2.key -config $DIR/ca2.conf

echo "Cross signing CA roots"
openssl x509 -req -days 36500 -in $DIR/ca1.csr -out $DIR/ca1-cross.crt -CA $DIR/ca2.crt -CAkey $DIR/ca2.key
openssl x509 -req -days 36500 -in $DIR/ca2.csr -out $DIR/ca2-cross.crt -CA $DIR/ca1.crt -CAkey $DIR/ca1.key

echo "Insert first yubikey"
read -p "Push enter to continue"

echo "Loading first key onto device"
yubico-piv-tool -s ${SLOT} -a import-key -i $DIR/ca1.key

echo "Loading first cross signed certificate onto device"
yubico-piv-tool -s ${SLOT} -a import-certificate -i $DIR/ca1-cross.crt

echo "Yubikey one status:"
yubico-piv-tool -a status

echo "Insert second yubikey"
read -p "Push enter to continue"

echo "Loading second key onto device"
yubico-piv-tool -s ${SLOT} -a import-key -i $DIR/ca2.key

echo "Loading second cross signed certificate onto device"
yubico-piv-tool -s ${SLOT} -a import-certificate -i $DIR/ca2-cross.crt

echo "Yubikey two status:"
yubico-piv-tool -a status

