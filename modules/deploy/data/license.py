#!/usr/bin/env python3
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

import os
import virl2_client as pcl
from time import sleep

# VIRL_USERNAME and VIRL_PASSWORD from the environment
nodes = os.getenv("CFG_LICENSE_NODES") or 0
token = os.getenv("CFG_LICENSE_TOKEN")
flavor = os.getenv("CFG_LICENSE_FLAVOR")
admin_user = os.getenv("CFG_APP_USER")
admin_pass = os.getenv("CFG_APP_PASS")

regid = (
    "regid.2019-10.com.cisco.CML_NODE_COUNT,1.0_2607650b-6ca8-46d5-81e5-e6688b7383c4"
)
client = pcl.ClientLibrary(
    "localhost", username=admin_user, password=admin_pass, ssl_verify=False
)

# this can fail as -dev0 builds already have the flavor set to enterprise!
try:
    client.licensing.set_product_license(flavor)
except pcl.exceptions.APIError as exc:
    print("uh-oh", exc)

try:
    client.licensing.register(token)
    if flavor == "CML_Enterprise":
        client.licensing.update_features({regid: int(nodes)})
except pcl.exceptions.APIError as exc:
    print("uh-oh", exc)

authorized = False
attempts = 24
while not authorized and attempts > 0:
    status = client.licensing.status()
    authorized = status["authorization"]["status"] == "IN_COMPLIANCE"
    attempts -= 1
    sleep(5)

if attempts == 0 and not authorized:
    print("system did not get into compliant state")
