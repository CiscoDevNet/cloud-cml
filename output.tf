#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

output "cml2info" {
  value = {
    "address" : module.deploy.public_ip
    "del" : "ssh -p1122 ${local.cfg.sys.user}@${module.deploy.public_ip} /provision/del.sh"
    "url" : "https://${module.deploy.public_ip}"
    "version" : module.ready.state.version
  }
}
