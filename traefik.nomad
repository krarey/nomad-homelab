job "traefik" {
  datacenters = ["byb"]
  type        = "system"

  group "traefik" {
    network {
      mode = "bridge"
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "http"

      connect {
        native = true
      }

      check {
        type     = "http"
        port     = "api"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.5.4"
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
        ]
      }

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "local/ca.pem"
        mode        = "file"
      }

      template {
        destination = "local/traefik.yml"
        data        = <<-EOF
          entryPoints:
            web:
              address: ":80"
            websecure:
              address: ":443"
          api:
            insecure: true
          ping: {}
          providers:
            consulCatalog:
              endpoint:
                tls:
                  ca: {{ env "NOMAD_TASK_DIR" }}/ca.pem
              prefix: traefik
              exposedByDefault: false
              connectAware: true
              connectByDefault: true
          certificatesResolvers:
            le-staging:
              acme:
                email: kyle@opt.sh
                storage: acme.json
                caServer: https://acme-staging-v02.api.letsencrypt.org/directory
                httpChallenge:
                  entrypoint: web
        EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

