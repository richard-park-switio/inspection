resource "google_os_config_os_policy_assignment" "screenpkg" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-screenpkg", zone)
    }
  }

  location = each.value.location
  name     = each.value.name

  instance_filter {
    all = false

    dynamic "exclusion_labels" {
      for_each = merge(
        {
          gke-node = {
            labels = { goog-gke-node = "" }
          }
        },
        {
          for vpc_access_connector in var.vpc_access_connectors
          : format("%s:%s", vpc_access_connector.region, vpc_access_connector.name) => {
            labels = { serverless-vpc-access = vpc_access_connector.name }
          }
        },
        {
          nat = {
            labels = { nat = "" }
          }
        }
      )

      content {
        labels = exclusion_labels.value.labels
      }
    }
  }

  os_policies {
    id   = "screenpkg"
    mode = "ENFORCEMENT"

    resource_groups {
      inventory_filters {
        os_short_name = "debian"
        os_version    = "10"
      }

      inventory_filters {
        os_short_name = "debian"
        os_version    = "11"
      }

      inventory_filters {
        os_short_name = "debian"
        os_version    = "12"
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "screen"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "rocky"
        os_version    = "8.*"
      }

      inventory_filters {
        os_short_name = "rocky"
        os_version    = "9.*"
      }

      resources {
        id = "epel"

        pkg {
          desired_state = "INSTALLED"

          yum {
            name = "epel-release"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          yum {
            name = "screen"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "ubuntu"
        os_version    = "20.04"
      }

      inventory_filters {
        os_short_name = "ubuntu"
        os_version    = "22.04"
      }

      resources {
        id = "wait-for-cloud-init"

        exec {
          enforce {
            interpreter = "SHELL"
            script      = "echo hello"
          }

          validate {
            interpreter = "SHELL"
            script      = "cloud-init status --wait; exit 100;"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "screen"
          }
        }
      }
    }
  }

  rollout {
    min_wait_duration = "0s"

    disruption_budget {
      fixed   = 0
      percent = 100
    }
  }

  skip_await_rollout = true
}

