#!/bin/bash

TOPDIR=$(dirname "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )")
mkdir $TOPDIR/ec2-instance-connect-1.0
cp -r $TOPDIR/src/opt $TOPDIR//ec2-instance-connect-1.0
tar -czf $TOPDIR/ec2-instance-connect-1.0.tar.gz -C $TOPDIR ec2-instance-connect-1.0/
rm -rf $TOPDIR/ec2-instance-connect-1.0/*
rmdir $TOPDIR/ec2-instance-connect-1.0
