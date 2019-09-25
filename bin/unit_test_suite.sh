#!/bin/bash

# Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

# Reads authorized keys blob $3 and prints verified, unexpired keys
# Openssl to use provided as $1
# Signer public key file path provided as $2

# Script to run our entire unit test suite.
# Iterates over the contents of test/input/direct and test/input/unsigned and validates we get the matching contents of unit-test/expected-output

OPENSSL="/usr/bin/openssl"
TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)")

tmpdir=$(mktemp -d /dev/shm/tmp-XXXXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT

# Generate test certificates
$TOPDIR/bin/unit-test/setup_certificates.sh "${OPENSSL}" $tmpdir
# Combine unittest & intermediate into the trust chain for the actual AuthorizedKeysCommand
cat $tmpdir/unittest.pem $tmpdir/intermediate.pem $tmpdir/ca.pem > $tmpdir/chain.pem

intermediate_fingerprint=$(openssl x509 -noout -fingerprint -sha1 -inform pem -in $tmpdir/intermediate.pem | sed -n 's/SHA1 Fingerprint=\(.*\)/\1/p' | tr -d ':')
unittest_fingerprint=$(openssl x509 -noout -fingerprint -sha1 -inform pem -in $tmpdir/unittest.pem | sed -n 's/SHA1 Fingerprint=\(.*\)/\1/p' | tr -d ':')

# Generate OCSP for those certificates
$TOPDIR/bin/unit-test/generate_ocsp.sh "${OPENSSL}" "${tmpdir}/intermediate.crt" "${tmpdir}/ca" "${tmpdir}/${intermediate_fingerprint}"
$TOPDIR/bin/unit-test/generate_ocsp.sh "${OPENSSL}" "${tmpdir}/unittest.crt" "${tmpdir}/intermediate" "${tmpdir}/${unittest_fingerprint}"

exit_status=0

# Direct input tests
for testfile in "${TOPDIR}"/unit-test/input/direct/* ; do
    filename="${testfile##*/}"
    $TOPDIR/bin/unit-test/test_authorized_keys.sh "${OPENSSL}" "${TOPDIR}/src/bin/eic_parse_authorized_keys" "${tmpdir}/chain.pem" "${tmpdir}/ca.crt" "${tmpdir}" "${testfile}" "${TOPDIR}/unit-test/expected-output/${filename}"
    if [ $? -ne 0 ] ; then
        exit_status=1
    fi
done

# Tests that require signing input data
for testdir in "${TOPDIR}"/unit-test/input/unsigned/* ; do
    # Generate signatures for key blobs
    filename="${testdir##*/}"
    $TOPDIR/bin/unit-test/sign_data.sh "${OPENSSL}" "${tmpdir}/unittest.key" "${testdir}" "${tmpdir}/${filename}"
    if [ $? -ne 0 ] ; then
        echo "Unable to run test ${filename}: signature generation failed"
    else
        # Run the actual test
        $TOPDIR/bin/unit-test/test_authorized_keys.sh "${OPENSSL}" "${TOPDIR}/src/bin/eic_parse_authorized_keys" "${tmpdir}/chain.pem" "${tmpdir}/ca.crt" "${tmpdir}" "${tmpdir}/${filename}" "${TOPDIR}/unit-test/expected-output/${filename}"
        if [ $? -ne 0 ] ; then
            exit_status=1
        fi
    fi
done

rm -rf $tmpdir

exit $exit_status
