job "promtail" {
  datacenters = ["*"]
  type        = "system"

  group "promtail" {
    network {
      port "http" {}
    }

    service {
      name = "promtail"
      port = "http"
      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "promtail" {
      driver = "docker"

      template {
        data = <<-EOT
          ---
          server:
            http_listen_port: {{ env "NOMAD_PORT_http" }}

          positions:
            # TODO: I should probably put this in a host volume to prevent duplicate log entries
            filename: /tmp/positions.yaml

          clients:
            - url: https://loki.service.consul/loki/api/v1/push
              tls_config:
                ca_file: {{ env "NOMAD_TASK_DIR" }}/ca.pem

          scrape_configs:
            - job_name: journald
              journal:
                labels:
                  job: systemd-journal
              relabel_configs:
                - source_labels:
                  - __journal__systemd_unit
                  target_label: systemd_unit
                - source_labels:
                  - __journal__hostname
                  target_label: nodename
                - source_labels:
                  - __journal_syslog_identifier
                  target_label: syslog_identifier
            - job_name: 'nomad-logs'
              consulagent_sd_configs:
                - server: '127.0.0.1:8500'
              relabel_configs:
                - source_labels: [__meta_consulagent_service]
                  action: drop
                  regex: '.+-sidecar-proxy'
                - source_labels: [__meta_consulagent_service_id]
                  action: keep
                  regex: '^_nomad-task-.*'
                - source_labels: [__meta_consulagent_node]
                  target_label: __host__
                - source_labels: [__meta_consulagent_service_metadata_external_source]
                  target_label: source
                - source_labels: [__meta_consulagent_service_id]
                  regex: '_nomad-task-([a-z0-9]*-[a-z0-9]*-[a-z0-9]*-[a-z0-9]*-[a-z0-9]*).*'
                  target_label:  task_id
                  replacement: $1
                - source_labels: [__meta_consulagent_service]
                  target_label: job
                - source_labels: ['__meta_consulagent_node']
                  target_label:  instance
                - source_labels: [__meta_consulagent_service_id]
                  regex: '_nomad-task-([a-z0-9]*-[a-z0-9]*-[a-z0-9]*-[a-z0-9]*-[a-z0-9]*).*'
                  target_label:  __path__
                  replacement: /var/lib/nomad/alloc/$1/alloc/logs/*std*.{?,??}
        EOT
        destination = "${NOMAD_TASK_DIR}/promtail-config.yaml"
      }

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "${NOMAD_TASK_DIR}/ca.pem"
        mode        = "file"
      }

      config {
        image        = "grafana/promtail:2.7.4"
        privileged   = true
        network_mode = "host"
        args = [
          "-config.file=${NOMAD_TASK_DIR}/promtail-config.yaml"
        ]

        mount {
          type     = "bind"
          target   = "/var/log/journal"
          source   = "/var/log/journal"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
        mount {
          type     = "bind"
          target   = "/etc/machine-id"
          source   = "/etc/machine-id"
          readonly = false
          bind_options {
            propagation = "rshared"
          }
        }
        mount {
          type     = "bind"
          target   = "/var/lib/nomad/alloc"
          source   = "/var/lib/nomad/alloc"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
