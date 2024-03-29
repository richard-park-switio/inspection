module "os_policy" {
  source                = "./os_policy"
  project               = local.project
  regions               = local.regions
  vpc_access_connectors = local.vpc_access_connectors
}
