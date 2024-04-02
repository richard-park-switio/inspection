resource "google_os_config_os_policy_assignment" "opsagent" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-opsagent", zone)
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
    id   = "opsagent"
    mode = "ENFORCEMENT"

    resource_groups {
      inventory_filters {
        os_short_name = "debian"
        os_version    = "10"
      }

      resources {
        id = "add-repo"

        repository {
          apt {
            archive_type = "DEB"
            components   = ["main"]
            distribution = "google-cloud-ops-agent-buster-2"
            gpg_key      = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
            uri          = "https://packages.cloud.google.com/apt"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "debian"
        os_version    = "11"
      }

      resources {
        id = "add-repo"

        repository {
          apt {
            archive_type = "DEB"
            components   = ["main"]
            distribution = "google-cloud-ops-agent-bullseye-2"
            gpg_key      = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
            uri          = "https://packages.cloud.google.com/apt"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "debian"
        os_version    = "12"
      }

      resources {
        id = "add-repo"

        repository {
          apt {
            archive_type = "DEB"
            components   = ["main"]
            distribution = "google-cloud-ops-agent-bookworm-2"
            gpg_key      = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
            uri          = "https://packages.cloud.google.com/apt"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "rocky"
        os_version    = "8.*"
      }

      resources {
        id = "add-repo"

        repository {
          yum {
            base_url     = "https://packages.cloud.google.com/yum/repos/google-cloud-ops-agent-el8-x86_64-2"
            display_name = "Google Cloud Ops Agent Repository"
            gpg_keys     = ["https://packages.cloud.google.com/yum/doc/yum-key.gpg", "https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg"]
            id           = "google-cloud-ops-agent"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          yum {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "rocky"
        os_version    = "9.*"
      }

      resources {
        id = "add-repo"

        repository {
          yum {
            base_url     = "https://packages.cloud.google.com/yum/repos/google-cloud-ops-agent-el9-x86_64-2"
            display_name = "Google Cloud Ops Agent Repository"
            gpg_keys     = ["https://packages.cloud.google.com/yum/doc/yum-key.gpg", "https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg"]
            id           = "google-cloud-ops-agent"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          yum {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
      inventory_filters {
        os_short_name = "ubuntu"
        os_version    = "20.04"
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
        id = "add-repo"

        repository {
          apt {
            archive_type = "DEB"
            components   = ["main"]
            distribution = "google-cloud-ops-agent-focal-2"
            gpg_key      = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
            uri          = "https://packages.cloud.google.com/apt"
          }
        }
      }

      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "google-cloud-ops-agent"
          }
        }
      }
    }

    resource_groups {
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
        id = "add-repo"

        repository {
          apt {
            archive_type = "DEB"
            components   = ["main"]
            distribution = "google-cloud-ops-agent-jammy-2"
            gpg_key      = "https://packages.cloud.google.com/apt/doc/apt-key.gpg"
            uri          = "https://packages.cloud.google.com/apt"
          }
        }
      }
      resources {
        id = "install-pkg"

        pkg {
          desired_state = "INSTALLED"

          apt {
            name = "google-cloud-ops-agent"
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

