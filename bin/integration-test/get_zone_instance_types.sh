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

# Load the list of instance types supported in a given zone.
# XXX: The mechanism for this is based on reserved instances. This may not be exhaustive in every zone.

region=$1
zone=$2

raw=$(aws ec2 describe-reserved-instances-offerings --filters "Name=availability-zone,Values=$zone" --region "${region}")
types=$(echo "{$raw}" | grep "InstanceType" | cut -d '"' -f 4)
echo "${types}"
