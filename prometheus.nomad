job "prometheus" {
  datacenters = ["byb"]

  group "prometheus" {
    network {
      mode = "bridge"
      port "http" {
        to = 9090
      }
    }

    volume "synology" {
      type            = "csi"
      source          = "prometheus"
      read_only       = false
      access_mode     = "multi-node-single-writer"
      attachment_mode = "file-system"
    }

    task "prometheus" {
      driver = "docker"
      config {
        image = "prom/prometheus:v2.32.0"
        args = [
          "--config.file=${NOMAD_TASK_DIR}/config/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.listen-address=0.0.0.0:9090",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
        ]
      }

      volume_mount {
        volume      = "synology"
        destination = "/prometheus"
        read_only   = false
      }

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "local/ca.pem"
        mode        = "file"
      }

      template {
        data          = <<EOH
---
global:
  scrape_interval: 30s
  evaluation_interval: 3s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
        - 0.0.0.0:9090
  - job_name: "nomad_server"
    metrics_path: "/v1/metrics"
    scheme: "https"
    params:
      format:
        - "prometheus"
    tls_config:
      ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
      server_name: "server.global.nomad"
    consul_sd_configs:
      - server: "consul.service.consul:8501"
        scheme: "https"
        datacenter: "byb"
        services:
          - "nomad"
        tags:
          - "http"
        tls_config:
          ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
  - job_name: "nomad_client"
    metrics_path: "/v1/metrics"
    scheme: "https"
    params:
      format:
        - "prometheus"
    tls_config:
      ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
      server_name: "client.global.nomad"
    consul_sd_configs:
      - server: "consul.service.consul:8501"
        scheme: "https"
        datacenter: "byb"
        services:
          - "nomad-client"
        tls_config:
          ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
  - job_name: envoy_metrics
    consul_sd_configs:
      - server: "consul.service.consul:8501"
        scheme: "https"
        datacenter: "byb"
        tls_config:
          ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
    relabel_configs:
      - source_labels:
          - __meta_consul_service
        action: drop
        regex: (.+)-sidecar-proxy
      - source_labels:
          - __meta_consul_service_metadata_metrics_port
        action: keep
        regex: (.+)
      - source_labels:
          - __meta_consul_address
          - __meta_consul_service_metadata_metrics_port
        regex: (.+);(\d+)
        replacement: $${1}:$${2}
        target_label: __address__
  - job_name: "node_exporter"
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "consul.service.consul:8501"
        scheme: "https"
        datacenter: "byb"
        tls_config:
          ca_file: "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
        services:
          - "prom-node-exporter"
EOH
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/prometheus.yml"
      }

      resources {
        cpu    = 500
        memory = 256
      }

      service {
        name = "prometheus"
        port = "http"
        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}
