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

# Test that package uninstall removes customizations and reinstall re-adds them

TOPDIR=$(dirname "$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" && pwd)")

while getopts ":i:p:z:u:k:l:t:" opt ; do
    case "${opt}" in
        i)
            instance_id="${OPTARG}"
            ;;
        p)
            public_ip="${OPTARG}"
            ;;
        z)
            zone="${OPTARG}"
            ;;
        u)
            osuser="${OPTARG}"
            ;;
        k)
            private_key="${OPTARG}"
            ;;
        l)
            distro="${OPTARG}"
            ;;
        t)
            package_path="${OPTARG}"
            ;;
        *)
            ;;
    esac
done

source "${TOPDIR}/integration-test/config/${distro}"

package_name="${package_path##*/}"

# Construct the test script
scriptfile=$(mktemp /tmp/tmp-XXXXXXXX)
trap 'rm -f "${scriptfile}"'  EXIT

if [ "${SSHD_CONFIG_MODIFIED}" -ne 0 ] ; then
    config_check="\"\$(sudo grep \"^AuthorizedKeysCommand[[:blank:]]/opt/aws/bin/eic_run_authorized_keys[[:blank:]]%u[[:blank:]]%f$\" /etc/ssh/sshd_config)\""
else
    config_check="-f /lib/systemd/system/${SSHD_SERVICE}.service.d/ec2-instance-connect.conf"
fi

echo '#!/bin/bash' > "${scriptfile}"
echo "set -e" >> "${scriptfile}"
printf "%s\n%s\n" "echo \"Uninstalling package\"" "${REMOVE} ec2-instance-connect 2>&1" >> "${scriptfile}"
printf "%s\n%s\n%s\n%s\n" "if [ ${config_check} ] ; then" "echo \"Package was not installed or deconfigured correctly\"" "exit 1" "fi" >> "${scriptfile}"
# We need an extra newline before the custom AKC due to some distros, eg RHEL, not having a newline at end of file
printf "%s\n%s\n" "echo \"Adding override config to sshd_config\"" "printf \"\n%s\n\" \"AuthorizedKeysCommand exit\" | sudo tee -a /etc/ssh/sshd_config" >> "${scriptfile}"
printf "%s\n%s\n" "echo \"Installing package\"" "${INSTALL} /tmp/${package_name} 2>&1" >> "${scriptfile}"
printf "%s\n%s\n%s\n%s\n" "if [ ${config_check} ] ; then" "echo \"Package overwrote existing customizations!\"" "exit 1" "fi" >> "${scriptfile}"

echo "scping test script to instance"
scp -i "${private_key}" -o StrictHostKeyChecking=no "${scriptfile}" "${osuser}@${public_ip}:/tmp/eic_custom_config_test.sh" 2>&1
scp_result="${?}"
if [ "${scp_result}" -ne 0 ] ; then
    exit 1
fi

echo "Running test script"
fail=0
ssh -i "${private_key}" -o StrictHostKeyChecking=no "${osuser}@${public_ip}" 'chmod +x /tmp/eic_custom_config_test.sh ; /tmp/eic_custom_config_test.sh' 2>&1
test_result="${?}"
if [ "${test_result}" -ne 0 ] ; then
    fail=1
fi

if [ "${fail}" -eq 0 ] ; then
    echo "Invoking EIC end-to-end test for final validation"
    "${TOPDIR}/integration-test/test/ssh_test.sh" -i "${instance_id}" -p "${public_ip}" -z "${zone}" -u "${osuser}" -k "${private_key}" -l "${distro}" -t "${package_path}" 2>&1
    ssh_result="${?}"
    if [ "${ssh_result}" -eq 0 ] ; then
        echo "ssh via EIC succeeded but should have failed!"
        fail=1
    fi
fi

# Reset back to start-of-test conditions
clean_cmd="${REMOVE} ec2-instance-connect  2>&1 ; sudo sed -i \"\~^AuthorizedKeysCommand[[:blank:]]exit\$~d\" /etc/ssh/sshd_config ; ${INSTALL} /tmp/${package_name} 2>&1"
ssh -i "${private_key}" -o StrictHostKeyChecking=no "${osuser}@${public_ip}" "${clean_cmd}"

exit $fail
