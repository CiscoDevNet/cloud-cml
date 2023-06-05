#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

# set

DEB="patty_0.2.9_amd64.deb"
APT_OPTS="-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew"
APT_OPTS+=" -o DPkg::Progress-Fancy=0 -o APT::Color=0"
DEBIAN_FRONTEND=noninteractive
export APT_OPTS DEBIAN_FRONTEND

aws s3 cp --no-progress s3://${BUCKET}/${DEB} /tmp

if [ ! -f /tmp/${DEB} ]; then
    echo "package not there. not installing..."
    exit
fi
apt-get install -y /tmp/${DEB}
GWDEV=$(ip -json route | jq -r '.[]|select(.dst=="default")|.dev')
echo "OPTS=\"-bridge $GWDEV -poll 30\"" >>/etc/default/patty.env
systemctl enable --now virl2-patty
