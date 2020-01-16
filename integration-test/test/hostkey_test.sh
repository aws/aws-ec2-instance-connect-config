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

# Test of EIC host key harvesting mechanism.  Regenerate rsa host key, re-trigger harvest, and ensure new key is returned.
# NOTE THIS TEST REQUIRES THE EC2 OS USER HAVE SUDO PERMISSION FOR SSH HOST KEY REGENERATION AND RESTARTING HOST KEY HARVEST

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

scriptfile=$(mktemp /tmp/tmp-XXXXXXXX)
trap 'rm -f "${scriptfile}"'  EXIT

cat > "${scriptfile}" << 'EOF'
#!/bin/bash

set -e

echo "Generating new host key"
keydir=$(mktemp -d /tmp/tmp-XXXXXXXX)
trap 'rm -rf "${keydir}"' EXIT
keyfile="${keydir}/eic_test_host_key"
ssh-keygen -t rsa -f "${keyfile}" -P '' -N '' -C '' -q

echo "Moving new host key to /etc/ssh"
sudo mv /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.bak
sudo mv /etc/ssh/ssh_host_rsa_key.pub /etc/ssh/ssh_host_rsa_key.pub.bak
sudo mv "${keyfile}" /etc/ssh/ssh_host_rsa_key
sudo mv "${keyfile}.pub" /etc/ssh/ssh_host_rsa_key.pub
sudo chmod 640 /etc/ssh/ssh_host_rsa_key
sudo chmod 644 /etc/ssh/ssh_host_rsa_key.pub
pubkey=$(cat /etc/ssh/ssh_host_rsa_key.pub | awk '{$1=$1};1')

echo "Retriggering host key harvesting"
sudo systemctl restart ec2-instance-connect.service

echo "Retrieving keys from service"
sign () {
    printf "${2}" | openssl dgst -binary -hex -sha256 -mac HMAC -macopt hexkey:"${1}" | sed 's/.* //'
}
getsigv4key () {
    local base=$(echo -n "AWS4${1}" | od -A n -t x1 | sed ':a;N;$!ba;s/[\n ]//g')
    local kdate=$(sign "${base}" "${2}")
    local kregion=$(sign "${kdate}" "${3}")
    local kservice=$(sign "${kregion}" "${4}")
    sign "${kservice}" "aws4_request"
}
IMDS_TOKEN="$(/usr/bin/curl -s -f -m 1 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 5")"
accountId=$(/usr/bin/curl -s -f -m 1 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "http://169.254.169.254/latest/dynamic/instance-identity/document" | grep -oP '(?<="accountId" : ")[^"]*(?=")')
domain=$(/usr/bin/curl -s -f -m 1 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "http://169.254.169.254/latest/meta-data/services/domain/")
zone=$(/usr/bin/curl -s -f -m 1 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "http://169.254.169.254/latest/meta-data/placement/availability-zone/")
region=$(echo "${zone}" | sed -n 's/\(\([a-z]\+-\)\+[0-9]\+\).*/\1/p')
instance=$(/usr/bin/curl -s -f -m 1 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "http://169.254.169.254/latest/meta-data/instance-id/")
val='{"AccountID":"'${accountId}'","AvailabilityZone":"'${zone}'","InstanceId":"'${instance}'"}'
creds=$(/usr/bin/curl -s -f -m 1 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" "http://169.254.169.254/latest/meta-data/identity-credentials/ec2/security-credentials/ec2-instance/")
AWS_ACCESS_KEY_ID=$(echo "${creds}" | sed -n 's/.*"AccessKeyId" : "\(.*\)",/\1/p')
AWS_SECRET_ACCESS_KEY=$(echo "${creds}" | sed -n 's/.*"SecretAccessKey" : "\(.*\)",/\1/p')
AWS_SESSION_TOKEN=$(echo "${creds}" | sed -n 's/.*"Token" : "\(.*\)",/\1/p')
host="ec2-instance-connect.${region}.${domain}"
endpoint="https://${host}"
timestamp=$(date -u "+%Y-%m-%d %H:%M:%S")
isoTimestamp=$(date -ud "${timestamp}" "+%Y%m%dT%H%M%SZ")
isoDate=$(date -ud "${timestamp}" "+%Y%m%d")
canonicalQuery=""
canonicalHeaders="host:${host}\nx-amz-date:${isoTimestamp}\nx-amz-security-token:${AWS_SESSION_TOKEN}\n"
signedHeaders="host;x-amz-date;x-amz-security-token"
payloadHash=$(echo -n "${val}" | sha256sum | sed 's/\s.*$//')
canonicalRequest="$(printf "POST\n/GetEC2HostKeys/\n%s\n${canonicalHeaders}\n${signedHeaders}\n%s" "${canonicalQuery}" "${payloadHash}")"
requestHash=$(echo -n "${canonicalRequest}" | sha256sum | sed 's/\s.*$//')
credentialScope="${isoDate}/${region}/ec2-instance-connect/aws4_request"
toSign="AWS4-HMAC-SHA256\n${isoTimestamp}\n${credentialScope}\n${requestHash}"
signingKey=$(getsigv4key "${AWS_SECRET_ACCESS_KEY}" "${isoDate}" "${region}" "ec2-instance-connect")
signature=$(sign "${signingKey}" "${toSign}")
authorizationHeader="AWS4-HMAC-SHA256 Credential=${AWS_ACCESS_KEY_ID}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}"
host_keys=$(curl -X POST -H "Content-Encoding: amz-1.0" -H "Authorization: ${authorizationHeader}" -H "Content-Type: application/json" -H "x-amz-content-sha256: ${payloadHash}" -H "x-amz-date: ${isoTimestamp}" -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" -H "x-amz-target: com.amazon.aws.sshaccessproxyservice.AWSEC2InstanceConnectService.GetEC2HostKeys" -d "${val}" "${endpoint}/GetEC2HostKeys/" 2>/dev/null)

echo "Verifying new key was harvested"
rsa_key=$(echo "ssh-rsa$(echo "${host_keys}" | sed -e 's/.*ssh-rsa\(.*\)\".*/\1/')")
if [ "${rsa_key}" = "${pubkey}" ] ; then
    echo "SUCCESS"
    exit 0
else
    echo "FAILURE"
    exit 1
fi
EOF
echo "scping test script to instance"
scp -i "${private_key}" -o StrictHostKeyChecking=no "${scriptfile}" "${osuser}@${public_ip}:/tmp/eic_host_key_test.sh" 2>&1
ssh_status=$?
if [ $ssh_status -eq 0 ] ; then
    echo "Running test script"
    ssh -i "${private_key}" -o StrictHostKeyChecking=no "${osuser}@${public_ip}" 'chmod +x /tmp/eic_host_key_test.sh ; /tmp/eic_host_key_test.sh' 2>&1
    ssh_status=$?
fi

exit "${ssh_status}"
