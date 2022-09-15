job "prometheus" {
  datacenters = ["byb"]

  group "prometheus" {
    network {
      mode = "bridge"
      # Exposed for Consul metrics proxy, which doesn't pass HTTP Host header
      # Otherwise this could be removed and metrics queried via Traefik ingress
      port "prometheus" {
        static = 9090
      }
    }

    volume "synology" {
      type            = "csi"
      source          = "prometheus-iscsi"
      read_only       = false
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    service {
      name = "prometheus"
      port = 9090
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prom.rule=Host(`prometheus.service.consul`)"
      ]
      check {
        name     = "Prometheus HTTP Probe"
        expose   = true
        type     = "http"
        path     = "/-/healthy"
        interval = "3s"
        timeout  = "1s"
      }
      connect {
        sidecar_service {}
      }
    }

    task "storage_init" {
      driver = "docker"
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      config {
        image   = "docker.io/library/alpine:latest"
        command = "/bin/sh"
        args = [
          "-c",
          "chown -R 65534:65534 /prometheus"
        ]
      }
      volume_mount {
        volume      = "synology"
        destination = "/prometheus"
        read_only   = false
      }

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
        data          = "{{ key \"prometheus/config\" }}"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/prometheus.yml"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
