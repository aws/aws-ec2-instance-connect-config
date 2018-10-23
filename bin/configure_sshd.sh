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

# Create/configure system user
/usr/bin/id -u "ec2-instance-connect" > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    /usr/bin/getent passwd ec2-instance-connect || /usr/sbin/useradd -r -M -s /sbin/nologin ec2-instance-connect
    /usr/sbin/usermod -L ec2-instance-connect
fi

modified=false

# Configure sshd to use EC2 Instance Connect's AuthorizedKeysCommand
AUTH_KEYS_CMD="AuthorizedKeysCommand /usr/bin/timeout 5s /opt/aws/bin/curl_authorized_keys %u %f"
AUTH_KEYS_USR="AuthorizedKeysCommandUser ec2-instance-connect"
# If the default, commented out none/nobody is present drop it
if ! grep -q "^.*AuthorizedKeysCommandRunAs[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
    if grep -q "^\#AuthorizedKeysCommand[[:blank:]]none$" /etc/ssh/sshd_config ; then
        if grep -q "^\#AuthorizedKeysCommandUser[[:blank:]]nobody$" /etc/ssh/sshd_config ; then
            sed -ir "/^\#AuthorizedKeysCommand[[:blank:]]none$/d" /etc/ssh/sshd_config
            sed -i "/^\#AuthorizedKeysCommandUser[[:blank:]]nobody$/d" /etc/ssh/sshd_config
            # We don't need to mark for restart - all we did was remove commented-out config
        fi
    fi
fi
if ! grep -q "^.*AuthorizedKeysCommand[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
    if ! grep -q "^.*AuthorizedKeysCommandUser[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
        if ! grep -q "^.*AuthorizedKeysCommandRunAs[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
            # Add our configuration
            printf "\n%s\n%s\n" "${AUTH_KEYS_CMD}" "${AUTH_KEYS_USR}" >> /etc/ssh/sshd_config
            modified=true
        fi
    fi
fi

if [ $modified = true ] ; then
    # Restart sshd
    # HACK: There is no good way to tell what init system is running.
    # "Best" solution is to just try them all
    sudo systemctl restart ssh || true
    sudo service sshd restart || true
    sudo /etc/init.d/sshd restart || true
fi
