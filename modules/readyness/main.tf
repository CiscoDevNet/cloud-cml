#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

data "cml2_system" "state" {
  timeout       = "10m"
  ignore_errors = true
}

# ignoring errors in the system data source deals with various error scenarios
# during the time the public IP of the AWS instance is known but not really
# reachable resulting in various "gateway timeouts", "service unavailable" or
# other, related errors. Especially in cases when going through a proxy.
