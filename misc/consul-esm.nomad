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

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "local/ca.pem"
        mode        = "file"
      }

      vault {
        policies      = ["consul-esm"]
        change_mode   = "restart"
      }

      template {
        destination = "secrets/consul-esm.hcl"
        data        = <<EOF
// The service name for this agent to use when registering itself with Consul.
consul_service = "consul-esm"

// The directory in the Consul KV store to use for storing runtime data.
consul_kv_path = "consul-esm/"

// The address of the local Consul agent. Can also be provided through the
// CONSUL_HTTP_ADDR environment variable.
http_addr = "unix://{{ env "NOMAD_SECRETS_DIR" }}/consul/consul.sock"

// The ACL token to use when communicating with the local Consul agent. Can
// also be provided through the CONSUL_HTTP_TOKEN environment variable.
token = "{{ with secret "consul/creds/consul-esm" }}{{ .Data.token }}{{ end }}"

// The Consul datacenter to use.
datacenter = "byb"

// The CA file to use for talking to Consul over TLS. Can also be provided
// though the CONSUL_CACERT environment variable.
ca_file = "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
EOF
      }
    }
  }
}
