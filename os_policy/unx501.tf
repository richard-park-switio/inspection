resource "google_os_config_os_policy_assignment" "unx501" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-unx501", zone)
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
    id   = "unx501"
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
              if [ ! -f /etc/rsyslog.d/91-unx501.conf ] ; then
                exit 101
              elif ! sudo stat -c %a /etc/rsyslog.d/91-unx501.conf | grep -qw '644' ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              cat << EOF | sudo tee /etc/rsyslog.d/91-unx501.conf
              *.info;mail.none;authpriv.none;cron.none /var/log/messages
              authpriv.* /var/log/secure
              mail.* /var/log/maillog
              cron.* /var/log/cron
              *.alert /dev/console
              *.emerg *
              EOF
              sudo systemctl restart rsyslog
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

