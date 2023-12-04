#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# set

APT_OPTS="-o Dpkg::Options::=--force-confmiss -o Dpkg::Options::=--force-confnew"
APT_OPTS+=" -o DPkg::Progress-Fancy=0 -o APT::Color=0"
DEBIAN_FRONTEND=noninteractive
export APT_OPTS DEBIAN_FRONTEND

source /provision/vars.sh
source /provision/copyfile.sh

# -rw-r--r--  1 rschmied  staff    1595644 Jan 15 12:31 iol-tools_0.1.4_amd64.deb
# -rw-r--r--  1 rschmied  staff  529327390 Jan 15 13:07 refplat-images-iol.deb

copyfile iol-tools_0.1.4_amd64.deb /tmp
copyfile refplat-images-iol.deb /tmp

apt-get install -y /tmp/iol-tools_0.1.4_amd64.deb /tmp/refplat-images-iol.deb

