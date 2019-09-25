#!/bin/bash

# Attempts to launch an instance to the given specification
# Outputs instance ID on success or where it failed otherwise

while getopts ":t:r:a:k:s:g:n:o:p:" opt ; do
    case "${opt}" in
        t)
            instance_type="${OPTARG}"
            ;;
        r)
            region="${OPTARG}"
            ;;
        a)
            ami_id="${OPTARG}"
            ;;
        k)
            key_name="${OPTARG}"
            ;;
        s)
            subnet_id="${OPTARG}"
            ;;
        g)
            security_group_id="${OPTARG}"
            ;;
        n)
            name_tag="${OPTARG}"
            ;;
        o)
            osuser="${OPTARG}"
            ;;
        p)
            private_key="${OPTARG}"
            ;;
        *)
            echo "Usage: $0 -t instance-type -r aws-region -a ami -k ec2-key-pair -s subnet -g security-group -n name-tag-value"
            exit 1
            ;;
    esac
done

launch_output=$(aws ec2 run-instances --region "${region}" --image-id "${ami_id}" --key-name "${key_name}" --security-group-ids "${security_group_id}" --subnet-id "${subnet_id}" --instance-initiated-shutdown-behavior "terminate" --instance-type "${instance_type}" --tag-specifications "[{\"ResourceType\":\"instance\",\"Tags\":[{\"Key\":\"Name\",\"Value\":\"${name_tag}\"}]}]")
launch_code=$?
if [ $launch_code -ne 0 ] ; then
    echo "Instance launch failed!"
    exit $launch_code
fi

instance_id=$(echo "${launch_output}" | grep \"InstanceId\" | cut -d '"' -f 4)
running=0
try="0"
# Wait up to 5 minutes for the instance to come up, checking every 5 seconds
while [ $try -lt 60 ] ; do
    aws ec2 describe-instances --instance-ids "${instance_id}" | grep "Name" | grep -q "running"
    launch_code=$?
    if [ $launch_code -eq 0 ] ; then
        try="60"
        running=1
    else
        try=$((try+1))
        sleep 5
    fi
done
if [ $running -eq 0 ] ; then
    echo "Timed out waiting for instance to enter 'running' state"
    exit 1
fi

# Wait a bit extra to let sshd come up
ssh_try="0"
public_ip=$(aws ec2 describe-instances --instance-ids "${instance_id}" | grep "PublicIp" | cut -d '"' -f 4 | uniq)
while [ $ssh_try -lt 30 ] ; do
    ssh -q -i "${private_key}" -o StrictHostKeyChecking=no "${osuser}@${public_ip}" exit 2>&1
    if [ $? -eq 0 ] ; then
        # Everything's ready
        echo "${instance_id}"
        exit 0
    fi
    ssh_try=$((ssh_try+1))
    sleep 10
done
echo "Timed out waiting for sshd to start on instance (or keypair is misconfigured)"
exit 1
