#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

source /provision/common.sh
source /provision/copyfile.sh
source /provision/vars.sh

if ! is_controller; then
    echo "not a controller, exiting"
    return
fi

# copy the converter wheel to the webserver dir
copyfile cml2tf-0.2.1-py3-none-any.whl /var/lib/nginx/html/client/

# stabilization timer
constants="/var/local/virl2/.local/lib/python3.8/site-packages/simple_drivers/constants.py"
sed -i -e'/^STABILIZATION_TIME = 3$/s/3/1/' $constants

# script to create users and resource limits
cat >/provision/users.py <<EOF
#!/usr/bin/env python3

import os
from time import sleep
from httpx import HTTPStatusError
from virl2_client import ClientLibrary

admin = os.getenv("CFG_APP_USER", "")
password = os.getenv("CFG_APP_PASS", "")
hostname = os.getenv("CFG_COMMON_HOSTNAME", "")

attempts = 6
while attempts > 0:
    try:
        client = ClientLibrary(f"https://{hostname}", admin, password, ssl_verify=False)
    except HTTPStatusError as exc:
        print(exc)
        sleep(10)
        attempts -= 1
    else:
        break

print(client)

USER_COUNT = 20

# create 20 users (and pod0 is for us to use, in total 21)

# the below block is to remove users again, used for testing
if False:
    for id in range(0, USER_COUNT + 1):
        user_id = client.user_management.user_id(f"pod{id}")
        client.user_management.delete_user(user_id)
    pools = client.resource_pool_management.resource_pools
    for id, pool in pools.items():
        if pool.is_template:
            template = pool
            continue
        pool.remove()
    template.remove()
    exit(0)

rp = client.resource_pool_management.create_resource_pool("pods", licenses=2, ram=2048)

for id in range(0, USER_COUNT + 1):
    client.user_management.create_user(f"pod{id}", f"{id:#02}DevWks{id:#02}", resource_pool=rp.id)
EOF

export CFG_APP_PASS CFG_COMMON_HOSTNAME
export HOME=/var/local/virl2
python3 /provision/users.py
