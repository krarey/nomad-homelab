job "traefik" {
  type = "system"

  update {
    max_parallel = 2
    stagger      = "30s"
  }

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
        image = "traefik:v2.9.9"
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
        destination = "${NOMAD_SECRETS_DIR}/wildcard-bundle.pem"
        change_mode = "script"
        data        = <<-EOT
          {{ with secret "pki-inter/issue/traefik" "common_name=*.service.consul" "format=pem" }}
          {{ .Data.certificate }}
          {{ .Data.issuing_ca }}{{ end }}
        EOT
        change_script {
          command       = "/bin/touch"
          args          = ["/local/dynamic-config.yaml"]
          fail_on_error = true
        }
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/wildcard-key.pem"
        change_mode = "noop" # The private key shouldn't rotate without the public certificate
        data        = <<-EOT
          {{ with secret "pki-inter/issue/traefik" "common_name=*.service.consul" "format=pem" }}
          {{ .Data.private_key }}{{ end }}
        EOT
      }


      template {
        destination = "${NOMAD_TASK_DIR}/traefik.yml"
        data        = <<-EOT
          api:
            insecure: false
            dashboard: true
          entryPoints:
            web:
              address: ":80"
            websecure:
              address: ":443"
          log:
            level: INFO
          ping: {}
          providers:
            file:
              filename: {{ env "NOMAD_TASK_DIR" }}/dynamic-config.yaml
              watch: true
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
          tracing:
            serviceName: traefik
            zipkin:
              httpEndpoint: http://tempo.service.consul:9411/api/v2/spans
        EOT
      }

      template {
        destination = "${NOMAD_TASK_DIR}/dynamic-config.yaml"
        change_mode = "noop" # Traefik watches the dynamic config on its own
        data        = <<-EOT
          tls:
            stores:
              default:
                defaultCertificate:
                  certFile: {{ env "NOMAD_SECRETS_DIR" }}/wildcard-bundle.pem
                  keyFile: {{ env "NOMAD_SECRETS_DIR" }}/wildcard-key.pem
          http:
            routers:
              dashboard:
                rule: Host(`traefik.service.consul`) && ((PathPrefix(`/api`) || PathPrefix(`/dashboard`)))
                tls: true
                service: api@internal
                entryPoints:
                  - traefik
                middlewares:
                  - auth
            middlewares:
              auth:
                digestAuth:
                  users:
                    - {{ with nomadVar "nomad/jobs/traefik/traefik/traefik" }}{{ .adminUser }}{{ end }}
              redirect-https:
                redirectScheme:
                  scheme: https
                  permanent: true
        EOT
      }

      vault {
        policies    = ["traefik"]
        change_mode = "noop"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}

