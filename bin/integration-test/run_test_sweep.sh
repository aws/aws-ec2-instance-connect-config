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

TOPDIR=$(dirname "$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" && pwd)")

while getopts ":i:p:k:u:z:o:l:f:" opt ; do
    case "${opt}" in
        i)
            instance_id="${OPTARG}"
            ;;
        p)
            public_ip="${OPTARG}"
            ;;
        k)
            keypath="${OPTARG}"
            ;;
        u)
            osuser="${OPTARG}"
            ;;
        z)
            zone="${OPTARG}"
            ;;
        o)
            output_directory="${OPTARG}"
            ;;
        l)
            distro="${OPTARG}"
            ;;
        f)
            package_path="${OPTARG}"
            ;;
        *)
            ;;
    esac
done

overall_success=0
for testscript in "${TOPDIR}"/integration-test/test/* ; do
    filename="${testscript##*/}"
    test_output=$($testscript -i "${instance_id}" -p "${public_ip}" -z "${zone}" -u "${osuser}" -k "${keypath}" -l "${distro}" -t "${package_path}")
    test_exit="${?}"
    if [ "${test_exit}" -ne 0 ] ; then
        echo "${test_output}" > "${output_directory}/${filename}"
        echo "Test ${filename} FAILED"
        overall_success=1
    else
        echo "Test ${filename} PASSED"
    fi
done

exit "${overall_success}"
