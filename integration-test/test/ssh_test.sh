#!/bin/bash

# Basic EIC functionality test: push a key and ssh to the instance

while getopts ":i:p:z:u:" opt ; do
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

echo "Testing EC2 Instance Connect end-to-end ssh functionality..."

keydir=$(mktemp -d /tmp/tmp-XXXXXXXX)
trap 'rm -rf "${keydir}"' EXIT

keyfile="${keydir}/eic_test_key"
ssh-keygen -t rsa -b 2048 -f "${keyfile}" -P "" -q

# We will make 3 tries as certain elements (eg network calls) may cause transient failure
try="0"
success=1

while [ $try -lt 3 ] ; do
    # Make 3 attempts to push a key
    awstry="0"
    while [ $awstry -lt 3 ] ; do
        aws ec2-instance-connect send-ssh-public-key --region us-west-2 --instance-id "${instance_id}" --availability-zone "${zone}" --instance-os-user "${osuser}" --ssh-public-key "file://${keyfile}.pub" 1>/dev/null
        aws_code=$?
        if [ $aws_code -ne 0 ] ; then
            sleep 5
            awstry=$((awstry+1))
            echo "${instance_id} EIC call ${awstry} failed"
        else
            awstry="3"
        fi
    done
    sshtry="0"
    # Make 3 attempts to ssh
    while [ $sshtry -lt 3 ] ; do
        ssh -q -i "${keyfile}" -o StrictHostKeyChecking=no "${osuser}@${public_ip}" exit 2>&1
        success=$?
        if [ $success -eq 0 ] ; then
            echo "${instance_id} ssh succeeded!"
            sshtry="3"
            try="3"
        else
            sleep 5
            sshtry=$((sshtry+1))
            echo "${instance_id} ssh call ${sshtry} failed"
        fi
    done
    if [ $success -ne 0 ] ; then
        try=$((try+1))
        echo "${instance_id} EIC test attempt ${try} failed"
    fi
done

if [ $success -eq 0 ] ; then
    echo "SUCCESS"
else
    echo "FAILURE"
fi

exit $success
