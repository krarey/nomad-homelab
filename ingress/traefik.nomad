job "traefik" {
  datacenters = ["byb", "x86"]
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
        image = "traefik:v2.9.8"
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
        ]
      }

      artifact {
        source      = "https://vault.service.consul:8200/v1/pki-root/ca/pem"
        destination = "${NOMAD_TASK_DIR}/ca.pem"
        mode        = "file"
      }

      template {
        destination   = "${NOMAD_SECRETS_DIR}/wildcard-bundle.pem"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data          = <<-EOT
          {{ with secret "pki-inter/issue/traefik" "common_name=*.service.consul" "format=pem" }}
          {{ .Data.certificate }}
          {{ .Data.issuing_ca }}{{ end }}
        EOT
      }

      template {
        destination   = "${NOMAD_SECRETS_DIR}/wildcard-key.pem"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data          = <<-EOT
          {{ with secret "pki-inter/issue/traefik" "common_name=*.service.consul" "format=pem" }}
          {{ .Data.private_key }}{{ end }}
        EOT
      }


      template {
        destination = "${NOMAD_TASK_DIR}/traefik.yml"
        data        = <<-EOT
          api:
            insecure: true
          entryPoints:
            web:
              address: ":80"
            websecure:
              address: ":443"
          ping: {}
          providers:
            file:
              filename: {{ env "NOMAD_TASK_DIR" }}/dynamic-config.yaml
            consulCatalog:
              cache: true
              connectAware: true
              connectByDefault: true
              defaultRule: "Host(`{{"{{"}} lower .Name {{"}}"}}.service.consul`)"
              endpoint:
                tls:
                  ca: {{ env "NOMAD_TASK_DIR" }}/ca.pem
              exposedByDefault: false
              prefix: traefik
              stale: true
          serversTransport:
            insecureSkipVerify: true # Traefik pulls IPs from Consul catalog, would need appropriate IP SANs on HTTPS upstreams
        EOT
      }

      template {
        destination   = "${NOMAD_TASK_DIR}/dynamic-config.yaml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        data          = <<-EOT
          tls:
            stores:
              default:
                defaultCertificate:
                  certFile: {{ env "NOMAD_SECRETS_DIR" }}/wildcard-bundle.pem
                  keyFile: {{ env "NOMAD_SECRETS_DIR" }}/wildcard-key.pem
          http:
            middlewares:
              redirect-https:
                redirectScheme:
                  scheme: https
                  permanent: true
        EOT
      }

      vault {
        policies      = ["traefik"]
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

