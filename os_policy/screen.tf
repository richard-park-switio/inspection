resource "google_os_config_os_policy_assignment" "screen" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-screen", zone)
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
    id   = "screen"
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
              if ! sudo grep -q 'idle' /etc/screenrc ; then
                exit 101
              elif [ ! -f /etc/profile.d/screen.sh ] ; then
                exit 101
              elif [ "$(sudo stat -c %a /etc/profile.d/screen.sh)" != "644" ] ; then
                exit 101
              elif [ ! -f /opt/cron/screen_left.sh ] ; then
                exit 101
              elif ! sudo grep -v '#' /etc/crontab | grep -q 'screen_left' ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              sudo sed '/detach/d' /etc/screenrc | sudo tee /etc/.screenrc
              echo 'idle 600 detach' | sudo tee -a /etc/.screenrc
              sudo mv /etc/.screenrc /etc/screenrc
              cat << EOF | sudo tee /etc/profile.d/screen.sh
              if [ "\$USER" != "root" ] && [ -z "\$STY" ]; then
                SCREEN_START=\$(date -d '+9 hour' '+%y%m%d%H%M%S.%s')
                SCREEN_SESSION=\$(echo "\$SCREEN_START" | sed 's/\./_/g')
                SCREEN_WHO=\$(whoami)
                if [ ! -d /tmp/.screen ] ; then
                  mkdir -p /tmp/.screen
                fi
                screen -L -Logfile "/tmp/.screen/\$SCREEN_WHO.\$SCREEN_START.log" -S "\$SCREEN_SESSION" /bin/bash --rcfile /etc/profile
                exit
              fi
              if [ -n "\$STY" ] ; then
                clear
                cat /etc/issue
                source ~/.bashrc
              fi
              EOF
              if [ ! -d /opt/cron ] ; then
                mkdir -p /opt/cron
              fi
              cat << EOF | sudo tee /opt/cron/screen_left.sh
              SCREEN_PROJECT_ID=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/project/project-id")
              SCREEN_ZONE=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/zone" | rev | cut -f 1 -d '/' | rev)
              SCREEN_INSTANCE_NAME=\$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/name")
              find /tmp/.screen ! -path '/tmp/.screen' -not -wholename "\$(ps aux | grep 'SCREEN' | grep -v 'root' | sed -n 's/.*\(\(\/tmp\/\.screen\/[^ ]*\)\).*/\1/p')" | while read -r SCREEN_LEFT_FILE ; do
                curl -s -X POST http://${var.inspection_ip_address}/history \
                  -F "file=@\$SCREEN_LEFT_FILE" \
                  -F "data={\"project_id\": \"\$SCREEN_PROJECT_ID\", \"zone\": \"\$SCREEN_ZONE\", \"instance_name\": \"\$SCREEN_INSTANCE_NAME\"}"
                rm -f "\$SCREEN_LEFT_FILE"
              done
              EOF
              sudo sed '/screen_left/d' /etc/crontab | sudo tee /etc/.crontab
              echo '* * * * * root /bin/bash /opt/cron/screen_left.sh' | sudo tee -a /etc/.crontab
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
