#!/bin/bash

# Script to run our entire unit test suite.
# Iterates over the contents of test/input/direct and test/input/unsigned and validates we get the matching contents of test/expected-output

OPENSSL="/usr/bin/openssl"
TOPDIR=$(dirname "$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" && pwd)")

tmpdir=$(mktemp -d /dev/shm/tmp-XXXXXXXX)
trap 'rm -rf "${tmpdir}"' EXIT

# Generate test certificates
$TOPDIR/bin/test/setup_certificates.sh "${OPENSSL}" $tmpdir
# Combine unittest & intermediate into the trust chain for the actual AuthorizedKeysCommand
cat $tmpdir/unittest.pem $tmpdir/intermediate.pem $tmpdir/ca.pem > $tmpdir/chain.pem

intermediate_fingerprint=$(openssl x509 -noout -fingerprint -sha1 -inform pem -in $tmpdir/intermediate.pem | sed -n 's/SHA1 Fingerprint=\(.*\)/\1/p' | tr -d ':')
unittest_fingerprint=$(openssl x509 -noout -fingerprint -sha1 -inform pem -in $tmpdir/unittest.pem | sed -n 's/SHA1 Fingerprint=\(.*\)/\1/p' | tr -d ':')

# Generate OCSP for those certificates
$TOPDIR/bin/test/generate_ocsp.sh "${OPENSSL}" "${tmpdir}/intermediate.crt" "${tmpdir}/ca" "${tmpdir}/${intermediate_fingerprint}"
$TOPDIR/bin/test/generate_ocsp.sh "${OPENSSL}" "${tmpdir}/unittest.crt" "${tmpdir}/intermediate" "${tmpdir}/${unittest_fingerprint}"

exit_status=0

# Direct input tests
for testfile in "${TOPDIR}"/test/input/direct/* ; do
    filename="${testfile##*/}"
    $TOPDIR/bin/test/test_authorized_keys.sh "${OPENSSL}" "${TOPDIR}/src/opt/aws/bin/parse_authorized_keys" "${tmpdir}/chain.pem" "${tmpdir}/ca.crt" "${tmpdir}" "${testfile}" "${TOPDIR}/test/expected-output/${filename}"
    if [ $? -ne 0 ] ; then
        exit_status=1
    fi
done

# Tests that require signing input data
for testdir in "${TOPDIR}"/test/input/unsigned/* ; do
    # Generate signatures for key blobs
    filename="${testdir##*/}"
    $TOPDIR/bin/test/sign_data.sh "${OPENSSL}" "${tmpdir}/unittest.key" "${testdir}" "${tmpdir}/${filename}"
    if [ $? -ne 0 ] ; then
        echo "Unable to run test ${filename}: signature generation failed"
    else
        # Run the actual test
        $TOPDIR/bin/test/test_authorized_keys.sh "${OPENSSL}" "${TOPDIR}/src/opt/aws/bin/parse_authorized_keys" "${tmpdir}/chain.pem" "${tmpdir}/ca.crt" "${tmpdir}" "${tmpdir}/${filename}" "${TOPDIR}/test/expected-output/${filename}"
        if [ $? -ne 0 ] ; then
            exit_status=1
        fi
    fi
done

rm -rf $tmpdir

exit $exit_status
