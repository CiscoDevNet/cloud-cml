#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

output "cml2info" {
  value = {
    "address" : module.deploy.public_ip
    "del" : nonsensitive("ssh -p1122 -i ~/.ssh/your_privkey_here ${local.cfg.secrets.sys.username}@${module.deploy.public_ip} /provision/del.sh")
    "url" : "https://${module.deploy.public_ip}"
    "version" : module.ready.state.version
  }
}

output "cml2secrets" {
  value     = local.cfg.secrets
  sensitive = true
}
