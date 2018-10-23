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

modified=false

# Remove EC2 Instance Connect sshd config if present
AUTH_KEYS_CMD="#AuthorizedKeysCommand none"
AUTH_KEYS_USER="#AuthorizedKeysCommandUser nobody"

# Remove EC2 Instance Connect sshd config if present
if grep -q "^AuthorizedKeysCommandUser[[:blank:]]ec2-instance-connect$" /etc/ssh/sshd_config ; then
    if grep -q "^AuthorizedKeysCommand[[:blank:]]/usr/bin/timeout[[:blank:]]5s[[:blank:]]/opt/aws/bin/curl_authorized_keys[[:blank:]]%u[[:blank:]]%f$" /etc/ssh/sshd_config ; then
        sed -ir "/^AuthorizedKeysCommand[[:blank:]]\/usr\/bin\/timeout[[:blank:]]5s[[:blank:]]\/opt\/aws\/bin\/curl_authorized_keys.*$/d" /etc/ssh/sshd_config
        sed -i "/^.*AuthorizedKeysCommandUser[[:blank:]]ec2-instance-connect$/d" /etc/ssh/sshd_config
        printf "\n%s\n%s\n" "#AuthorizedKeysCommand none" "#AuthorizedKeysCommandUser nobody" >> /etc/ssh/sshd_config
        modified=true
    fi
fi

if [ $modified = true ] ; then
    # Restart sshd
    # HACK: There is absolutely no good way to tell what init system is running.
    # "Best" solution is to just try them all
    sudo systemctl restart ssh || true
    sudo service sshd restart || true
    sudo /etc/init.d/sshd restart || true
fi


/usr/bin/id -u "ec2-instance-connect" > /dev/null 2>&1
if [ $? -eq 0 ] ; then
    # Delete system user
    /usr/sbin/userdel ec2-instance-connect
fi
