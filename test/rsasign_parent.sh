#!/bin/bash

set -eufx

export OPENSSL_ENGINES=${PWD}/.libs
export LD_LIBRARY_PATH=$OPENSSL_ENGINES:${LD_LIBRARY_PATH-}
export PATH=${PWD}:${PATH}

PHANDLE=0x81010001

DIR=$(mktemp -d)
echo -n "abcde12345abcde12345">${DIR}/mydata.txt

# Create an Primary key pair
echo "Generating primary key"
PARENT_CTX=${DIR}/primary_owner_key.ctx

tpm2_startup -T mssim -c || true

tpm2_createprimary -T mssim -H o -g sha256 -G rsa -C ${PARENT_CTX}

# Load primary key to persistent handle
HANDLE=$(tpm2_evictcontrol -T mssim -A o -c ${PARENT_CTX} -S ${PHANDLE} | cut -d ' ' -f 2)

# Generating a key underneath the persistent parent
tpm2tss-genkey -a rsa -s 2048 -p abc -P ${HANDLE} ${DIR}/mykey

echo "abc" | openssl rsa -engine tpm2tss -inform engine -in ${DIR}/mykey -pubout -outform pem -out ${DIR}/mykey.pub -passin stdin
cat ${DIR}/mykey.pub

echo "abc" | openssl pkeyutl -engine tpm2tss -keyform engine -inkey ${DIR}/mykey -sign -in ${DIR}/mydata.txt -out ${DIR}/mysig -passin stdin

cat ${DIR}/mysig

#this is a workaround because -verify allways exits 1
R="$(openssl pkeyutl -pubin -inkey ${DIR}/mykey.pub -verify -in ${DIR}/mydata.txt -sigfile ${DIR}/mysig || true)"
if ! echo $R | grep "Signature Verified Successfully" >/dev/null; then
    echo $R
    exit 1
fi
