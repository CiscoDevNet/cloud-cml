#!/usr/bin/env python3
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

import os
import sys
from time import sleep

import virl2_client as pcl


def set_license() -> str:
    nodes = os.getenv("CFG_LICENSE_NODES") or 0
    token = os.getenv("CFG_LICENSE_TOKEN") or ""
    flavor = os.getenv("CFG_LICENSE_FLAVOR")
    admin_user = os.getenv("CFG_APP_USER")
    admin_pass = os.getenv("CFG_APP_PASS")
    if len(token) == 0:
        print("no token provided")
        return ""

    regid = "regid.2019-10.com.cisco.CML_NODE_COUNT,1.0_2607650b-6ca8-46d5-81e5-e6688b7383c4"
    client = pcl.ClientLibrary(
        "localhost", username=admin_user, password=admin_pass, ssl_verify=False
    )

    try:
        client.licensing.set_product_license(flavor)
    except pcl.exceptions.APIError as exc:
        return str(exc)

    try:
        client.licensing.register(token)
        nn = int(nodes)
        if flavor == "CML_Enterprise" and nn > 0:
            client.licensing.update_features({regid: nn})
    except pcl.exceptions.APIError as exc:
        return str(exc)

    authorized = False
    attempts = 24
    while not authorized and attempts > 0:
        status = client.licensing.status()
        authorized = status["authorization"]["status"] == "IN_COMPLIANCE"
        attempts -= 1
        sleep(5)

    if attempts == 0 and not authorized:
        return "system did not get into compliant state"
    return ""


if __name__ == "__main__":
    exit_code = 0
    result = set_license()
    if len(result) > 0:
        exit_code = 1
        print(result)
    sys.exit(exit_code)
