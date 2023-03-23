job "prometheus-consul-exporter" {
  datacenters = ["byb"]

  group "consul-exporter" {
    network {
      mode = "bridge"
      port "metrics" {}
    }

    service {
      name = "prometheus-consul-exporter"
      port = "metrics"
      check {
        name     = "Readiness Probe"
        type     = "http"
        path     = "/-/ready"
        interval = "10s"
        timeout  = "4s"
      }
    }

    task "exporter" {
      driver = "docker"
      config {
        image = "prom/consul-exporter:v0.9.0"
        args = [
          "--web.listen-address=:${NOMAD_PORT_metrics}",
          "--consul.server=https://consul.service.consul:8501",
          "--consul.ca-file=${NOMAD_TASK_DIR}/ca.pem"
        ]
      }


      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "${NOMAD_TASK_DIR}/ca.pem"
        mode        = "file"
      }

      resources {
        cpu    = 200
        memory = 12
      }
    }
  }
}
