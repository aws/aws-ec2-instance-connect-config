#!/bin/bash

# Unit test helper.  Takes a directory containing key blobs in files, signs the data in each, and consolidates into a final output.

if [ -z "${1}" ] ; then
    echo "No openssl provided"
    exit 1
fi

if [ -z "${2}" ] ; then
    echo "Signing key not provided."
    exit 2
fi

if [ -z "${3}" ] ; then
    echo "Input directory not provided."
    exit 3
fi

if [ -z "${4}" ] ; then
    echo "Target file not provided."
    exit 4
fi

OPENSSL="${1}"
private_key="${2}"
input_dir="${3}"
target="${4}"

signing_temp=$(mktemp -d /dev/shm/tmp-XXXXXXXX)
trap 'rm -rf "${signing_temp}"' EXIT

for file in "${input_dir}"/* ; do
    # Generate the signature
    $OPENSSL dgst -sha256 -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:32 -sign $private_key -out $signing_temp/signature $file
    # Base64 encode it
    base64 $signing_temp/signature > $signing_temp/encoded
    # Add the input file dump & its signature to the target
    cat $file $signing_temp/encoded >> $target
    # Append a newline
    echo >> $target
done
