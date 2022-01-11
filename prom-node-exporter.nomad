job "prom-node-exporter" {
  datacenters = ["byb"]
  type        = "system"

  group "node-exporter" {
    network {
      mode = "bridge"
      port "metrics" {}
    }

    service {
      name = "prom-node-exporter"
      port = "metrics"

      check {
        type     = "tcp"
        port     = "metrics"
        interval = "10s"
        timeout  = "1s"
      }
    }

    task "node-exporter" {
      driver = "exec"

      config {
        command = "${NOMAD_TASK_DIR}/node_exporter-1.3.1.linux-arm64/node_exporter"
        args    = ["--web.listen-address=:${NOMAD_PORT_metrics}"]
      }

      artifact {
        source = "https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-arm64.tar.gz"
      }
    }
  }
}

