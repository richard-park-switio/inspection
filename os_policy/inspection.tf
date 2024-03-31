resource "google_os_config_os_policy_assignment" "inspection" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-inspection", zone)
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
    id   = "inspection"
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
              if [ ! -f /opt/cron/inspection.sh ] ; then
                exit 101
              elif [ ! -f /opt/inspection/Linux.sh ] ; then
                exit 101
              elif [ "$(sudo stat -c %a /opt/inspection/Linux.sh)" != "755" ] ; then
                exit 101
              elif ! sudo grep -v '#' /etc/crontab | grep -q 'inspection' ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              if [ ! -d /opt/inspection ] ; then
                mkdir -p /opt/inspection
              fi
              sudo curl http://${var.inspection_ip_address}/Linux.sh -o /opt/inspection/Linux.sh
              sudo chmod +x /opt/inspection/Linux.sh
              cat << EOF | sudo tee /opt/cron/inspection.sh
              INSPECTION_PROJECT_ID=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")
              INSPECTION_ZONE=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | rev | cut -f 1 -d '/' | rev)
              INSPECTION_INSTANCE_NAME=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/name")
              echo -e "1\n1\n0" | /opt/inspection/Linux.sh
              sudo curl -s -X POST http://${var.inspection_ip_address}/uraw \
                -F "file=@SERVER_UNIX_\$INSPECTION_INSTANCE_NAME.uraw" \
                -F "data={\"project_id\": \"\$INSPECTION_PROJECT_ID\", \"zone\": \"\$INSPECTION_ZONE\"}"
              sudo rm -f "SERVER_UNIX_\$INSPECTION_INSTANCE_NAME.uraw"
              EOF
              sudo sed '/inspection/d' /etc/crontab | sudo tee /etc/.crontab
              echo '*/5 * * * * root /bin/bash /opt/cron/inspection.sh' | sudo tee -a /etc/.crontab
              sudo mv /etc/.crontab /etc/crontab
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
