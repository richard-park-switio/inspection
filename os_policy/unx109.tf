resource "google_os_config_os_policy_assignment" "unx109" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-unx109", zone)
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
    id   = "unx109"
    mode = "ENFORCEMENT"

    resource_groups {
      dynamic "inventory_filters" {
        for_each = toset([
          { os_short_name = "debian", os_version = "10" },
          { os_short_name = "debian", os_version = "11" },
          { os_short_name = "debian", os_version = "12" },
          { os_short_name = "rocky", os_version = "8.*" },
          { os_short_name = "rocky", os_version = "9.*" },
          { os_short_name = "ubuntu", os_version = "20.04" },
          { os_short_name = "ubuntu", os_version = "22.04" }
        ])

        content {
          os_short_name = inventory_filters.value.os_short_name
          os_version    = inventory_filters.value.os_version
        }
      }

      resources {
        id = "configuration"

        exec {
          validate {
            interpreter = "SHELL"

            script = <<-EOT
              if ! sudo grep -v '#' /etc/crontab | grep -q 'ls /home' ; then
                exit 101
              fi
              for TARGET in games lp mail news uucp ; do
                if sudo cut -f 1 -d ':' /etc/passwd | grep -q "$TARGET" ; then
                  exit 101
                elif sudo cut -f 1 -d ':' /etc/group | grep -q "$TARGET" ; then
                  exit 101
                fi
              done
              exit 100
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              sudo sed '/userdel/d' /etc/crontab | sudo tee /etc/.crontab
              echo '00 15 * * * root ls /home | while read -r USER ; do if [ -d "/home/$USER" ] ; then if [ "$(find /home/$USER -mindepth 1 -maxdepth 1 ! -name ".*" -type f | wc -l) == '0' ] ; then userdel -r \$USER" ; fi ; fi ; done' | sudo tee -a /etc/.crontab
              sudo mv /etc/.crontab /etc/crontab
              for TARGET in games lp mail news uucp ; do
                if sudo grep -q "$TARGET" /etc/passwd ; then
                  sudo userdel "$TARGET"
                elif sudo grep -q "$TARGET" /etc/group ; then
                  sudo groupdel "$TARGET"
                fi
              done
              exit 100
            EOT
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

