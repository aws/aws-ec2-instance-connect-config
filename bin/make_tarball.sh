#!/bin/bash

# Copyright 2012-2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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

TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
mkdir $TOPDIR/ec2-instance-connect-1.0
cp -r $TOPDIR/src/opt $TOPDIR//ec2-instance-connect-1.0
tar -czf $TOPDIR/ec2-instance-connect-1.0.tar.gz -C $TOPDIR ec2-instance-connect-1.0/
rm -rf $TOPDIR/ec2-instance-connect-1.0/*
rmdir $TOPDIR/ec2-instance-connect-1.0
