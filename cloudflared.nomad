job "cloudflare-tunnel" {
  datacenters = ["byb"]
  type        = "system"

  group "cloudflared" {
    network {
      port "metrics" {}
    }

    service {
      name = "cloudflare-tunnel"
      port = "metrics"

      check {
        type     = "http"
        port     = "metrics"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "cloudflared" {
      driver = "exec"

      config {
        command = "cloudflared-linux-arm"
        args    = ["tunnel", "--config", "${NOMAD_TASK_DIR}/config.yml", "run"]
      }

      artifact {
        source = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm"
      }

      template {
        destination = "secrets/tunnel.json"
        data        = <<-EOF
        {
          "AccountTag": "755a069db2dd82aaafcea6940be92ed1",
          "TunnelSecret": "{{ with secret "kv/cloudflare/nomad" }}{{ .Data.data.secret }}{{ end }}",
          "TunnelID": "267c5f44-0933-4077-bbf8-d1568b2d6624",
          "TunnelName": "nomad"
        }
        EOF
      }

      template {
        destination = "local/config.yml"
        data        = <<-EOF
        tunnel: 267c5f44-0933-4077-bbf8-d1568b2d6624
        credentials-file: {{ env "NOMAD_SECRETS_DIR" }}/tunnel.json
        metrics: 0.0.0.0:{{ env "NOMAD_PORT_metrics" }}
        no-autoupdate: true
        ingress:
          - service: http://localhost:80
        EOF
      }

      vault {
        policies      = ["cloudflare-tunnels"]
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}

