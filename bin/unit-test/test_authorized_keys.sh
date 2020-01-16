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

# Authorized keys command unit test script.  Takes the script to test, certificate, CA, input, and expected output.

# TODO: Switch to named args/getopts

if [ -z "${1}" ] ; then
    echo "No openssl provided"
    exit 1
fi

if [ -z "${2}" ] ; then
    echo "Script file not provided"
    exit 2
fi

if [ -z "${3}" ] ; then
    echo "No certificate file provided"
    exit 3
fi

if [ -z "${4}" ] ; then
    echo "No CA file provided"
    exit 4
fi

if [ -z "${5}" ] ; then
    echo "OCSP responses directory not provided"
    exit 5
fi

if [ -z "${6}" ] ; then
    echo "No input file provided"
    exit 6
fi

if [ -z "${7}" ] ; then
    echo "No expected output file provided"
    exit 7
fi

OPENSSL=$1
certificate=$(cat "${3}")
filename="${6##*/}"

expected_output=$(cat "${7}")
expected_exit=0
if [ -z "${expected_output}" ] ; then
    # If expected output is empty then we expect the script not to exit success
    expected_exit=255
fi

testdir=$(mktemp -d /dev/shm/tmp-XXXXXXXX)

# The key fingerprint is for a pre-generated ssh key used in several test inputs
# Some test inputs contain other keys as well
# The test outputs, however, *only* match this key - we expect the other keys to be rejected
test_output=$(${2} -x true -p "${6}" -o "${OPENSSL}" -d "${testdir}" -s "${certificate}" -i "i-abcd1234" -c "unittest.managedssh.amazonaws.com" -a "${4}" -v "${5}" -f "SHA256:F3e4S8/QjcVquqrvmyq9AWAhOxIXfpbpnmDVFdA0sPU")
test_status=$?

exit_status=0
if [[ $test_status -eq $expected_exit && "${test_output}" = "${expected_output}" ]] ; then
    echo "${filename} PASSED"
else
    echo "${filename} FAILED"
    echo "EXPECTED: exit ${expected_exit} with output"
    echo "${expected_output}"
    echo "ACTUAL: exit ${test_status} with output"
    echo "${test_output}"
    exit_status=1
fi

rm -rf "${testdir}"

exit "${exit_status}"
