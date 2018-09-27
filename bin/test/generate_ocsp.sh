#!/bin/bash

# Copyright 2012-2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
# http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

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

tmpfile=$(mktemp /dev/shm/tmp-XXXXXXXX)

# Generate the OCSP request

$1 ocsp -no_nonce -issuer $3.crt -cert $2 -VAfile $3.crt -reqout $tmpfile

# Generate the response
# Yes, we're using the CA to sign the response as well.  Since this is for unit testing use we don't need strict security.
$1 ocsp -index $3.db.index -rsigner $3.crt -rkey $3.key -CA $3.crt -VAfile $3.crt -reqin $tmpfile -respout $4 > /dev/null 2>&1

# Drop the request, we don't need it anymore
rm -f $tmpfile
