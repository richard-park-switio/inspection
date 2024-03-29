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
              if ! sudo crontab -l | grep -v '#' | grep -q 'ls /home' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/passwd | grep -q 'games' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/passwd | grep -q 'lp' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/passwd | grep -q 'mail' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/passwd | grep -q 'news' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/passwd | grep -q 'uucp' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/group | grep -q 'games' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/group | grep -q 'lp' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/group | grep -q 'mail' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/group | grep -q 'news' ; then
                exit 101
              elif sudo cut -f 1 -d ':' /etc/group | grep -q 'uucp' ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              sudo crontab -l | sed '/userdel/d' | sudo crontab -
              echo '15 00 * * * ls /home | while read -r user ; do if [ -d "/home/$user" ] ; then if [ "$(find /home/$user -mindepth 1 -maxdepth 1 ! -name ".*" -type f | wc -l) == '0' ] ; then userdel -r \$user" ; fi ; fi ; done' | sudo crontab -
              for target in games lp mail news uudp ; then
                if sudo grep -q "$target" /etc/passwd ; then
                  sudo userdel -r "$target"
                elif sudo grep -q "$target" /etc/group ; then
                  sudo groupdel "$target"
                fi
              fi
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

