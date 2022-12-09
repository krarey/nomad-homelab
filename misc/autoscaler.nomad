job "nomad-autoscaler" {
  datacenters = ["byb"]
  group "autoscaler" {
    network {
      mode = "bridge"
    }

    service {
      name = "nomad-autoscaler"
      port = 8080
      check {
        expose   = true
        type     = "http"
        path     = "/v1/health"
        interval = "5s"
        timeout  = "2s"
      }
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 9090
            }
          }
        }
      }
    }

    task "autoscaler" {
      driver = "docker"
      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "${nomad_task_dir}/ca.pem"
        mode        = "file"
      }
      config {
        image   = "hashicorp/nomad-autoscaler:0.3"
        command = "nomad-autoscaler"
        args = [
          "agent",
          "-config",
          "${nomad_task_dir}/config.hcl"
        ]
        ports = ["http"]
      }

      template {
        destination = "${nomad_task_dir}/config.hcl"
        data        = <<eof
nomad {
  address = "https://nomad.service.consul:4646"
  ca_cert = "{{ env "nomad_task_dir" }}/ca.pem"
  token   = "{{ with secret "nomad/creds/autoscale" }}{{ .data.secret_id }}{{ end }}"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://localhost:9090"
  }
}

target "nomad" {
  driver = "nomad-target"
}

strategy "threshold" {
  driver = "threshold"
}

strategy "target-value" {
  driver = "target-value"
}
eof
      }

      resources {
        cpu    = 50
        memory = 128
      }

      vault {
        policies      = ["nomad-autoscale"]
        change_mode   = "signal"
        change_signal = "sighup"
      }
    }
  }
}
