job "vault" {
  datacenters = ["byb"]

  group "vault" {
    count = 3

    constraint {
      operator = "distinct_hosts"
      value    = "true"
    }

    network {
      mode = "bridge"
      port "cluster" {
        static = 8202
      }
      port "metrics" {
        to = 9102
      }
    }

    volume "synology" {
      type            = "csi"
      source          = "vault-safe"
      read_only       = false
      per_alloc       = true
      access_mode     = "multi-node-single-writer"
      attachment_mode = "file-system"
    }

    service {
      name = "safe"
      port = 8200

      check {
        expose    = true
        name      = "Vault Health"
        type      = "http"
        path      = "/v1/sys/health"
        interval  = "10s"
        timeout   = "2s"
        on_update = "ignore_warnings"
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "safe"
              local_bind_port  = 9200
            }
            config {
              envoy_prometheus_bind_addr = "0.0.0.0:9102"
            }
          }
        }
      }

      # tags = [
      #   "traefik.enable=true",
      #   "traefik.http.middlewares.safe-redir-https.redirectscheme.scheme=https",
      #   "traefik.http.routers.safe-https.rule=Host(`safe.opt.sh`)",
      #   "traefik.http.routers.safe-https.tls=true",
      #   "traefik.http.routers.safe-https.tls.certresolver=le-staging",
      #   "traefik.http.routers.safe-http.rule=Host(`safe.opt.sh`)",
      #   "traefik.http.routers.safe-http.middlewares=safe-redir-https",
      # ]

      meta {
        metrics_port = "${NOMAD_HOST_PORT_metrics}"
      }
    }

    task "vault" {
      driver = "docker"

      config {
        image   = "hashicorp/vault:1.9.1"
        command = "vault"
        args = [
          "server",
          "-config",
          "${NOMAD_TASK_DIR}/vault.hcl"
        ]
      }

      resources {
        cpu    = 1500
        memory = 256
      }

      env {
        SKIP_SETCAP = true
      }

      volume_mount {
        volume      = "synology"
        destination = "/raft"
        read_only   = false
      }


      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "local/ca.pem"
        mode        = "file"
      }

      template {
        destination = "local/vault.hcl"
        data        = <<-EOF
        api_addr      = "https://safe.opt.sh"
        cluster_addr  = "https://{{ env "NOMAD_ADDR_cluster" }}"
        disable_mlock = true
        ui            = true

        listener "tcp" {
          address         = "127.0.0.1:8200"
          cluster_address = "0.0.0.0:8202"
          tls_disable     = true
        }

        storage "raft" {
          path    = "/raft"
          node_id = "{{ env "node.unique.name" }}"

          retry_join {
            leader_api_addr = "http://127.0.0.1:9200"
          }
        }

        seal "transit" {
          address         = "https://vault.service.consul:8200"
          disable_renewal = "true"
          mount_path      = "safe-seal/"
          key_name        = "safe-key"
          tls_ca_cert     = "{{ env "NOMAD_TASK_DIR" }}/ca.pem"
        }
        EOF
      }

      vault {
        policies      = ["safe-seal"]
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
