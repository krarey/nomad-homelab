job "consul-esm" {
  datacenters = ["byb"]

  group "consul-esm" {
    count = 2

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
        image = "hashicorp/consul-esm:0.6.0"
        args = ["-config-file=${NOMAD_SECRETS_DIR}/consul-esm.hcl"]
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
        policies      = ["consul-esm"]
        change_mode   = "restart"
      }

      template {
        destination = "secrets/consul-esm.hcl"
        data        = <<EOF
// The address of the local Consul agent. Can also be provided through the
// CONSUL_HTTP_ADDR environment variable.
http_addr = "unix://{{ env "NOMAD_SECRETS_DIR" }}/consul/consul.sock"

// The ACL token to use when communicating with the local Consul agent. Can
// also be provided through the CONSUL_HTTP_TOKEN environment variable.
token = "{{ with secret "consul/creds/consul-esm" }}{{ .Data.token }}{{ end }}"
EOF
      }
    }
  }
}
