job "tempo" {
  datacenters = ["byb"]

  group "tempo" {
    count = 1

    network {
      mode = "bridge"

      port "grpc" {
        to = 9095
      }
      port "http" {
        to = 3200
      }
      port "zipkin_http" {
        static = 9411
      }
    }

    # TODO: Onboard this to service mesh once storage and config are properly sorted out
    service {
      name = "tempo"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.tempo-tls.tls=true",
        "traefik.http.routers.tempo.middlewares=redirect-https@file",
        "traefik.consulcatalog.connect=false"
      ]
    }

    task "tempo" {
      driver = "docker"

      config {
        image = "grafana/tempo:2.1.1"
        args = [
          "--config.file=/etc/tempo/config/tempo.yml",
        ]
        volumes = [
          "local/config:/etc/tempo/config",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      template {
        data = <<-EOT
          server:
            http_listen_port: 3200
          distributor:
            receivers:
              zipkin:
          ingester:
            trace_idle_period: 10s
            max_block_bytes: 1_000_000
            max_block_duration: 5m
          compactor:
            compaction:
              compaction_window: 1h
              max_block_bytes: 100_000_000
              block_retention: 1h
              compacted_block_retention: 10m
          storage:
            trace:
              backend: local
              wal:
                path: /tmp/tempo/wal
              local:
                path: /tmp/tempo/blocks
              pool:
                max_workers: 100
                queue_depth: 10000
        EOT

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/tempo.yml"
      }
    }
  }
}
