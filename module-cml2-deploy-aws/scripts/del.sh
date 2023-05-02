#!/bin/bash

#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2023, Cisco Systems, Inc.
# All rights reserved.
#

# NOTE: vars with dollar curly brace are HCL template vars, getting replaced
# by Terraform with actual values before the script is run!
#
# If a dollar curly brace is needed in the shell script itself, it needs to be
# written as $${VARNAME} (two dollar signs)
#
# NOTE: this only works as long as the admin user password wasn't changed
# from the value which was orginally provisioned.

# set -x
# set -e


function cml_remove_license() {
    API="http://ip6-localhost:8001/api/v0"

    # re-auth with new password
    TOKEN=$(echo '{"username":"${app.user}","password":"${app.pass}"}' \ |
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
