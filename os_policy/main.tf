data "google_project" "default" {
  project_id = var.project.id
}

data "google_compute_zones" "this" {
  project = data.google_project.default.project_id

  for_each = {
    for region in var.regions
    : region => { region = region }
  }

  region = each.value.region
}

resource "google_compute_project_metadata" "default" {
  project = data.google_project.default.project_id

  metadata = {
    enable-os-inventory = true
    enable-osconfig     = true
    enable-oslogin      = true
  }
}
