#!/bin/bash

# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

# Amazon Linux has its installed CAs in a single file called "ca-bundle.crt".  We point to that directly instead of just the ssl certs dir.

/bin/sed -ir "/^ca_path=\/etc\/ssl\/certs$/cca_path=\/etc\/ssl\/certs\/ca-bundle.crt" /opt/aws/bin/curl_authorized_keys
