job "loki" {
  datacenters = ["byb"]

  group "loki" {
    network {
      mode = "bridge"
    }

    volume "synology" {
      type            = "csi"
      source          = "loki-iscsi"
      read_only       = false
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    service {
      name = "loki"
      port = 3100
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.rule=Host(`loki.service.consul`)"
      ]
      check {
        name     = "Loki HTTP Probe"
        expose   = true
        type     = "http"
        path     = "/ready"
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
          "chown -R 10001:10001 /loki"
        ]
      }
      volume_mount {
        volume      = "synology"
        destination = "/loki"
        read_only   = false
      }
    }
    task "loki" {
      driver = "docker"
      config {
        image = "grafana/loki:2.6.0"
      }
      volume_mount {
        volume      = "synology"
        destination = "/loki"
        read_only   = false
      }
      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
