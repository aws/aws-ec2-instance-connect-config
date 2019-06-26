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

# Note: this will only work on a system with rpm build tools installed (ie, RHEL & its derivatives)

if [ $# -ne 2 ] ; then
    echo "Usage: make_rpm.sh [version] [release]"
    echo "    ie, make_rpm.sh [1.1] [1]"
    exit 1
fi

TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
BUILDDIR=$TOPDIR/rpmbuild
mkdir -p $BUILDDIR

version=$1
release=$2

mkdir -p $BUILDDIR/{BUILD,RPMS,SOURCES,SPECS,SRPMS,ec2-instance-connect-${version},tmp}
mkdir -p $BUILDDIR/ec2-instance-connect-$version/opt/aws/bin
cp $TOPDIR/rpmsrc/SPECS/generic.spec $BUILDDIR/SPECS/ec2-instance-connect.spec
cp $TOPDIR/src/bin/* $BUILDDIR/ec2-instance-connect-$version/opt/aws/bin/
cp $TOPDIR/rpmsrc/.rpmmacros $BUILDDIR/

/bin/sed -i "s%^ca_path=/etc/ssl/certs$%ca_path=/etc/ssl/certs/ca-bundle.crt%" $BUILDDIR/ec2-instance-connect-$version/opt/aws/bin/eic_curl_authorized_keys

# Trick rpmbuild into thinking this is homedir to read .rpmmacros
REALHOME=$HOME
export HOME=$BUILDDIR

function cleanup {
    export HOME=$REALHOME
    rm -rf $BUILDDIR/${BUILD,SOURCES,tmp}
    rm -rf $BUILDDIR/BUILDROOT # In case we got far enough for this to exist
    rm -rf $BUILDDIR/ec2-instance-connect-$version
}
trap cleanup EXIT

cp $TOPDIR/src/rpm_systemd/ec2-instance-connect.service $BUILDDIR/SOURCES/
ls $BUILDDIR/SOURCES

cd $BUILDDIR # Will ensure some paths are set correctly in rpmbuild

# Compress the scripts
tar -czf $BUILDDIR/SOURCES/ec2-instance-connect-$version.tar.gz ec2-instance-connect-$version/

# Fill in the placeholders
sed -i "s/\!VERSION\!/${version}/" $BUILDDIR/SPECS/ec2-instance-connect.spec
sed -i "s/\!RELEASE\!/${release}/" $BUILDDIR/SPECS/ec2-instance-connect.spec

# Build the package
rpmbuild -ba -bs $BUILDDIR/SPECS/ec2-instance-connect.spec

cp $BUILDDIR/RPMS/noarch/ec2-instance-connect-$version-$release.noarch.rpm $TOPDIR/
