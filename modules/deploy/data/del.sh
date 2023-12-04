#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#
#
# NOTE: this only works as long as the admin user password wasn't changed
# from the value which was originally provisioned.

# set -x
# set -e


source /provision/vars.sh


function cml_remove_license() {
    API="http://ip6-localhost:8001/api/v0"

    # re-auth with new password
    TOKEN=$(echo '{"username":"'${CFG_APP_USER}'","password":"'${CFG_APP_PASS}'"}' \ |
        curl -s -d@- $API/authenticate | jq -r)

    # de-register the license from the controller
    curl -s -X "DELETE" \
        "$API/licensing/deregistration" \
        -H "Authorization: Bearer $TOKEN" \
        -H "accept: application/json" \
        -H "Content-Type: application/json"
}


# only de-register when the target is active
if [ $(systemctl is-active virl2.target) = "active" ]; then
    cml_remove_license
else
    echo "CML is not active, license can not be de-registered!"
    exit 255
fi
