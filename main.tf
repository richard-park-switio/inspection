module "os_policy" {
  source                = "./os_policy"
  project               = local.project
  regions               = local.regions
  vpc_access_connectors = local.vpc_access_connectors
  inspection_ip_address = local.inspection_ip_address
}
