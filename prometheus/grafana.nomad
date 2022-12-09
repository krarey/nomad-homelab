job "grafana" {
  datacenters = ["byb"]

  group "grafana" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "grafana"
      port = 3000
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=Host(`grafana.service.consul`)"
      ]
      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }
      check {
        name     = "Grafana HTTP Probe"
        expose   = true
        type     = "http"
        path     = "/api/health"
        interval = "5s"
        timeout  = "1s"
      }
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9090
            }
            upstreams {
              destination_name = "loki"
              local_bind_port = 3100
            }
          }
        }
      }
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:9.0.2"
        volumes = [
          "local/config/grafana.ini:/etc/grafana/grafana.ini",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

            template {
        data = <<EOH
[feature_toggles]
enable = tempoSearch tempoBackendSearch
EOH

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/grafana.ini"
      }
    }
  }
}
