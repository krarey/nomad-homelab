job "consul-esm" {
  datacenters = ["byb"]

  group "consul-esm" {
    count = 1

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      mode = "bridge"
    }

    volume "consul-api" {
      type   = "host"
      source = "consul-api"
    }

    task "esm" {
      driver = "docker"

      config {
        image = "hashicorp/consul-esm:0.7.1"
      }

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "${NOMAD_TASK_DIR}/ca.pem"
        mode        = "file"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      volume_mount {
        volume      = "consul-api"
        destination = "${NOMAD_SECRETS_DIR}/consul"
      }

      vault {
        policies    = ["consul-esm"]
        change_mode = "restart"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/consul.env"
        env         = true
        data        = <<-EOT
          CONSUL_HTTP_ADDR = "unix://{{ env "NOMAD_SECRETS_DIR" }}/consul/consul.sock"
          CONSUL_HTTP_TOKEN = "{{ with secret "consul/creds/consul-esm" }}{{ .Data.token }}{{ end }}"
        EOT
      }
    }
  }
}
