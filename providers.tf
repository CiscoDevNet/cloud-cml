provider "cml2" {
  alias       = "controller"
  address     = module.deploy.controller_address
  username    = module.deploy.controller_username
  password    = module.deploy.controller_password
  skip_verify = true
  timeout     = "30m"
}
