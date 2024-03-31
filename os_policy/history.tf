resource "google_os_config_os_policy_assignment" "history" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-history", zone)
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
        }
      )

      content {
        labels = exclusion_labels.value.labels
      }
    }
  }

  os_policies {
    id   = "history"
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
              if [ ! -f /etc/profile.d/history.sh ] ; then
                exit 101
              elif [ "$(sudo stat -c %a /etc/profile.d/history.sh)" != "644" ] ; then
                exit 101
              elif [ ! -f /etc/rsyslog.d/89-history.conf ] ; then
                exit 101
              elif [ "$(sudo stat -c %a /etc/rsyslog.d/89-history.conf)" != "644" ] ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              cat << EOF | sudo tee /etc/profile.d/history.sh
              function logging {
                LOGGING_LAST_COMMAND=\$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')
                LOGGING_WHO=\$(whoami)
                logger -p local0.notice -t history "\$LOGGING_WHO COMMAND: \$LOGGING_LAST_COMMAND"
              }

              PROMPT_COMMAND="logging"
              EOF
              cat << EOF | sudo tee /etc/rsyslog.d/89-history.conf
              local0.notice /var/log/messages
              EOF
              sudo systemctl restart rsyslog
              if [ ! -f /var/log/messages ] ; then
                sudo touch /var/log/messages
              fi
              sudo chown root:adm /var/log/messages
              sudo chmod 640 /var/log/messages
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
