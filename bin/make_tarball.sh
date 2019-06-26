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

TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")

verrel=$(cat $TOPDIR/VERSION)
version=${verrel%-*}
pkgver="ec2-instance-connect-${version}"

mkdir -p $TOPDIR/$pkgver/opt/aws/bin
cp $TOPDIR/src/bin/* $TOPDIR/$pkgver/opt/aws/bin/
if [ $# -eq 1 ] ; then # TODO: better check.  Low-priority.
    /bin/sed -i "s%^ca_path=/etc/ssl/certs$%ca_path=/etc/ssl/certs/ca-bundle.crt%" $TOPDIR/$pkgver/opt/aws/bin/eic_curl_authorized_keys
fi
tar -czf $TOPDIR/$pkgver.tar.gz -C $TOPDIR $pkgver/
rm -rf $TOPDIR/$pkgver/*
rmdir $TOPDIR/$pkgver
