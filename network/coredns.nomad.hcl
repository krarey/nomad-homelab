job "coredns" {

  affinity {
    attribute = "${attr.cpu.arch}"
    value     = "arm64"
  }
  
  group "dns" {
    network {
      port "dns" {
        static = 1053
      }
      port "health" {
        to = 8080
      }
    }

    task "server" {
      driver = "podman"

      config {
        image = "ghcr.io/krarey/coredns-nomad:main"
        ports = ["dns", "health"]
        args  = ["-conf", "${NOMAD_TASK_DIR}/Corefile", "-dns.port", "1053"]
      }

      service {
        name     = "hostmaster"
        provider = "nomad"
        port     = "dns"
        check {
          type     = "http"
          port     = "health"
          path     = "/health"
          interval = "5s"
          timeout  = "2s"
        }
      }

      identity {
        env = true
      }

      template {
        destination   = "${NOMAD_TASK_DIR}/Corefile"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        perms         = "644"
        data          = <<-EOF
          service.nomad. {
            errors
            health
            nomad {
              zone service.nomad
              address unix://{{ env "NOMAD_SECRETS_DIR" }}/api.sock
              ttl 10
            }
            cache 30
          }
          EOF
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}