#!/bin/bash

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
    test_exit=$?
    if [ $test_exit -ne 0 ] ; then
        echo "${test_output}" > "${output_directory}/${filename}"
        echo "Test ${filename} FAILED"
        overall_success=1
    else
        echo "Test ${filename} PASSED"
    fi
done

exit $overall_success
