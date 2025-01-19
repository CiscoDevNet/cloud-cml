#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2024, Cisco Systems, Inc.
# All rights reserved.
#

# Local variables for configuration processing
locals {
  # Load and decode the YAML configuration file
  raw_cfg = yamldecode(file(var.cfg_file))

  # Merge configuration excluding secrets, then add processed secrets from the secrets module
  # This ensures secrets are properly managed and not exposed in raw form
  cfg = merge(
    {
      for k, v in local.raw_cfg : k => v if k != "secret"
    },
    {
      secrets = module.secrets.secrets
    }
  )

  # Process extra configuration variables if provided
  # If cfg_extra_vars is a file path, read the file; otherwise use the value directly
  extras = var.cfg_extra_vars == null ? "" : (
    fileexists(var.cfg_extra_vars) ? file(var.cfg_extra_vars) : var.cfg_extra_vars
  )
}

# Secrets management module
# Handles secure storage and retrieval of sensitive information like passwords and API keys
module "secrets" {
  source = "./modules/secrets"
  cfg    = local.raw_cfg
}

# Deployment module
# Manages the creation and configuration of CML infrastructure in the chosen cloud provider
module "deploy" {
  source = "./modules/deploy"
  cfg    = local.cfg
  extras = local.extras
  providers = {
    cml2.controller = cml2.controller
  }
}

# CML2 Provider Configuration
# Sets up the connection to the CML controller using the deployed instance's public IP
provider "cml2" {
  address        = "https://${module.deploy.public_ip}"
  username       = local.cfg.secrets.app.username
  password       = local.cfg.secrets.app.secret
  skip_verify    = true    # Skip SSL verification as CML may use self-signed certificates
  dynamic_config = true    # Allow dynamic configuration updates
}

# Readiness Check Module
# Verifies that the CML instance is fully operational and ready to accept connections
module "ready" {
  source = "./modules/readyness"
  providers = {
    cml2 = cml2.controller
  }
  depends_on = [module.deploy]  # Ensure deployment is complete before checking readiness
}
