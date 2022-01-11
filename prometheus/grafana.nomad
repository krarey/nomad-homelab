job "grafana" {
  datacenters = ["byb"]

  group "grafana" {
    network {
      mode = "bridge"
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"
    }

    task "grafana" {
      driver = "docker"
      config {
        image = "grafana/grafana:8.3.3"
        ports = ["http"]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}