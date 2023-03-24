job "cloudflare-tunnel" {
  datacenters = ["byb"]

  group "cloudflared" {
    count = 2
    network {
      mode = "bridge"
    }

    service {
      name = "cloudflare-tunnel"
      port = 8080

      check {
        type     = "http"
        expose   = true
        path     = "/ready"
        interval = "10s"
        timeout  = "4s"
      }
    }

    task "cloudflared" {
      driver = "docker"

      config {
        image = "cloudflare/cloudflared:latest"
        args = [
          "tunnel",
          "--no-autoupdate",
          "--metrics",
          "0.0.0.0:8080",
          "run"
        ]
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/cloudflared.env"
        env         = true
        data        = "TUNNEL_TOKEN={{ with nomadVar \"nomad/jobs/cloudflare-tunnel\" }}{{ .token }}{{ end }}"
      }
    }
  }
}

