#!/bin/bash

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
    # HACK: There is absolutely no good way to tell what init system is running.
    # "Best" solution is to just try them all
    sudo systemctl restart ssh || true
    sudo service sshd restart || true
    sudo /etc/init.d/sshd restart || true
fi
