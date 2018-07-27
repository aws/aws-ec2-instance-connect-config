#!/bin/bash

# Unit test helper to generate an OCSP response in the desired location

if [ -z "${1}" ] ; then
    echo "No openssl provided"
    exit 1
fi

if [ -z "${2}" ] ; then
    echo "No certificate file provided"
    exit 2
fi

if [ -z "${3}" ] ; then
    echo "No CA filepath provided (do not include file extension - this path will be used with .crt, .key, and .cdb.index)"
    exit 3
fi

if [ -z "${4}" ] ; then
    echo "No output file specified"
    exit 4
fi

tmpfile=$(mktemp /tmp/tmp-XXXXXXXX)

# Generate the OCSP request

$1 ocsp -no_nonce -issuer $3.crt -cert $2 -VAfile $3.crt -reqout $tmpfile

# Generate the response
# Yes, we're using the CA to sign the response as well.  Since this is for unit testing use we don't need strict security.
$1 ocsp -index $3.db.index -rsigner $3.crt -rkey $3.key -CA $3.crt -VAfile $3.crt -reqin $tmpfile -respout $4 > /dev/null 2>&1

# Drop the request, we don't need it anymore
rm -f $tmpfile
