resource "google_os_config_os_policy_assignment" "unx314" {
  project = data.google_project.default.project_id

  for_each = {
    for zone in flatten([
      for region in var.regions
      : data.google_compute_zones.this[region].names
    ])
    : zone => {
      location = zone
      name     = format("%s-unx314", zone)
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
    id   = "unx314"
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
              if [ -f /etc/motd ] ; then
                exit 101
              elif sudo grep -v '#' /etc/pam.d/login | grep -q 'pam_motd' ; then
                exit 101
              elif sudo grep -v '#' /etc/pam.d/sshd | grep -q 'pam_motd' ; then
                exit 101
              elif ! sudo grep -q 'Swit' /etc/issue ; then
                exit 101
              elif ! sudo grep -q 'Swit' /etc/issue.net ; then
                exit 101
              else
                exit 100
              fi
            EOT
          }

          enforce {
            interpreter = "SHELL"

            script = <<-EOT
              sudo rm -f /etc/motd
              if sudo grep -v '#' /etc/pam.d/login | grep -q 'pam_motd' ; then
                sudo sed '/pam_motd/d' /etc/pam.d/login | sudo tee /etc/pam.d/.login
                sudo mv /etc/pam.d/.login /etc/pam.d/login
              fi
              if sudo grep -v '#' /etc/pam.d/sshd | grep -q 'pam_motd' ; then
                sudo sed '/pam_motd/d' /etc/pam.d/sshd | sudo tee /etc/pam.d/.sshd
                sudo mv /etc/pam.d/.sshd /etc/pam.d/sshd
              fi
              cat << EOF | sudo tee /etc/issue
              ********************************************************************
                This system is for the use of authorized users only. Usage of
                this system may be monitored and recorded by system personnel.

                Anyone using this system expressly consents to such monitoring
                and is advised that if such monitoring reveals possible
                evidence of criminal activity, system personnel may provide the
                evidence from such monitoring to law enforcement officials.

                Illegal access may be subject to legal sanctions

                © 2019 by Swit Technologies Inc. All rights reserved.
              ********************************************************************
              EOF
              cat << EOF | sudo tee /etc/issue.net
              ********************************************************************
                This system is for the use of authorized users only. Usage of
                this system may be monitored and recorded by system personnel.

                Anyone using this system expressly consents to such monitoring
                and is advised that if such monitoring reveals possible
                evidence of criminal activity, system personnel may provide the
                evidence from such monitoring to law enforcement officials.

                Illegal access may be subject to legal sanctions

                © 2019 by Swit Technologies Inc. All rights reserved.
              ********************************************************************
              EOF
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

