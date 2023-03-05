job "waypoint-static-runner" {
  datacenters = ["x86"]
  group "waypoint-runner" {
    task "pre_task" {
      driver = "docker"
      config {
        image   = "busybox:latest"
        command = "sh"
        args = [
          "-c",
          "chown -R 100:1000 /data/"
        ]
      }
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      resources {
        cpu    = 200
        memory = 10
      }
      volume_mount {
        volume      = "waypoint-runner"
        destination = "/data"
      }
    }

    task "runner" {
      driver = "docker"
      config {
        image          = "hashicorp/waypoint:0.11.0"
        auth_soft_fail = false
        args = [
          "runner",
          "agent",
          "-id=static",
          "-state-dir=/data/runner",
          "-vv"
        ]
      }
      # NOMAD_* vars are set via API due to on-demand runners
      env {
        WAYPOINT_SERVER_ADDR            = "waypoint-server.service.consul:9701"
        WAYPOINT_SERVER_TLS             = "true"
        WAYPOINT_SERVER_TLS_SKIP_VERIFY = "true"
      }
      resources {
        cpu    = 200
        memory = 600
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/runner.env"
        env         = true
        data        = <<-EOT
          {{ with secret "kv/waypoint/runner" }}
          WAYPOINT_SERVER_TOKEN={{ .Data.data.token }}
          WAYPOINT_SERVER_COOKIE={{ .Data.data.cookie }}
          {{ end }}
        EOT
      }
      volume_mount {
        volume      = "waypoint-runner"
        destination = "/data"
      }
      vault {
        policies = ["waypoint-runner"]
      }
    }

    volume "waypoint-runner" {
      type   = "host"
      source = "waypoint_runner"
    }
  }
}
