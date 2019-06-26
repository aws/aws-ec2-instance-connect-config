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

# XXX: This script builds a local 3.0 (native) package for testing purposes.
# Any actual patches should be developed and submitted using apt-source and Quilt.

# Note: this will only work on a system with dpkg build tools installed (ie, Debian & its derivatives)
# It is also strongly recommended you install devtools (dch, etc) to assist with package building
# You are *REQUIRED* to have debhelper and devscripts installed!

if [ $# -ne 2 ] ; then
    echo "Usage: make_deb.sh [version] [release]"
    echo "    ie, make_deb.sh [1.1] [1]"
    exit 1
fi

md5 () {
    /bin/echo -n "${val}" | /usr/bin/md5sum | /bin/sed 's/\s.*$//'
}

sha1 () {
    /bin/echo -n "${val}" | /usr/bin/sha1sum | /bin/sed 's/\s.*$//'
}

sha256 () {
    /bin/echo -n "${val}" | /usr/bin/sha256sum | /bin/sed 's/\s.*$//'
}

TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")

version=$1
release=$2
pkgdir="${TOPDIR}/ec2-instance-connect-${version}-${release}"

# Copy source files
mkdir $pkgdir
mkdir -p $pkgdir/ec2-instance-connect
cp $TOPDIR/src/bin/* $pkgdir/ec2-instance-connect/
# Dump /bin, /usr/bin, etc from binary paths names since we want to use $PATH on Ubuntu/etc
sed -i "s%/usr/bin/%%g" $pkgdir/ec2-instance-connect/*
sed -i "s%^/bin/%%g" $pkgdir/ec2-instance-connect/*
sed -i "s%\([^\#][^\!]\)/bin/%\1%g" $pkgdir/ec2-instance-connect/*
# Copy ec2-instance-connect service file
cp -r $TOPDIR/src/deb_systemd/ec2-instance-connect.service $pkgdir/

mkdir $pkgdir/debian
cp -r $TOPDIR/debian/* $pkgdir/debian/
sed -i "s/\!VERSION\!/${version}-${release}/" $pkgdir/debian/control

# Do the actual packaging
return_dir=$(pwd)
cd $pkgdir
debuild

# Clean up
cd $return_dir
rm -rf $pkgdir
