#!/bin/bash

# Load the list of instance types supported in a given zone.
# XXX: The mechanism for this is based on reserved instances. This may not be exhaustive in every zone.

region=$1
zone=$2

raw=$(aws ec2 describe-reserved-instances-offerings --filters "Name=availability-zone,Values=$zone" --region "${region}")
types=$(echo "{$raw}" | grep "InstanceType" | cut -d '"' -f 4)
echo "${types}"
