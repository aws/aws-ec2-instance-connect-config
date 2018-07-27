#!/bin/bash

# Create/configure system user
/usr/bin/getent passwd ec2-instance-connect || /usr/sbin/useradd -r -M -s /sbin/nologin ec2-instance-connect
/usr/sbin/usermod -L ec2-instance-connect

# Configure sshd to use EC2 Instance Connect's AuthorizedKeysCommand
AUTH_KEYS_CMD="AuthorizedKeysCommand /opt/aws/bin/curl_authorized_keys %u %f"
if grep -q "^.*AuthorizedKeysCommand[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
    sudo sed -i "/^.*AuthorizedKeysCommand[[:blank:]]\+.*$/c${AUTH_KEYS_CMD}" /etc/ssh/sshd_config
else
    sudo printf "\n%s" "${AUTH_KEYS_CMD}" >> /etc/ssh/sshd_config
fi

# Configure the runas user for AuthorizedKeysCommand
AUTH_KEYS_USR="AuthorizedKeysCommandUser ec2-instance-connect"
if grep -q "^.*AuthorizedKeysCommandUser[[:blank:]]\+.*$" /etc/ssh/sshd_config ; then
    sudo sed -i "/^.*AuthorizedKeysCommandUser[[:blank:]]\+.*$/c${AUTH_KEYS_USR}" /etc/ssh/sshd_config
else
    sudo printf "\n%s" "${AUTH_KEYS_USR}" >> /etc/ssh/sshd_config
fi

# Restart sshd
if command -v systemctl ; then
    # systemd
    if systemctl is-active --quiet sshd ; then
        sudo systemctl restart sshd
    fi
elif command -v service ; then
    # sysv
    if sudo service sshd status 1>/dev/null ; then
        sudo service sshd restart
    fi
else
    # Check for basic process & rerun init.d
    if (( $(ps -ef | grep -v grep | grep sshd | wc -l) > 0 )) ; then
        sudo /etc/init.d/sshd restart
    fi
fi
