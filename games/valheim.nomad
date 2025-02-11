job "valheim" {
  datacenters = ["byb"]
  
  constraint {
    attribute = "${attr.cpu.arch}"
    value     = "amd64"
  }

  group "game" {
    network {
      mode = "bridge"
      port "game1" {
        static = 2456
      }
      port "game2" {
        static = 2457
      }
    }

    volume "valheim_data" {
      type   = "host"
      source = "valheim_data"
    }

    volume "valheim_config" {
      type   = "host"
      source = "valheim_config"
    }

    task "server" {
      driver = "docker"
      service {
        name     = "valheim"
        provider = "nomad"
        port     = "game1"
      }
      env {
        SERVER_NAME   = "Valheimestry"
        WORLD_NAME    = "valheimestry"
        SERVER_PUBLIC = "false"
        UPDATE_CRON   = "0 */3 * * *"
        TZ            = "America/New_York"
        PUID          = 1024
        PGID          = 1024
      }
      config {
        image = "ghcr.io/lloesche/valheim-server"
      }
      resources {
        cpu    = 5800
        memory = 6144
      }
      template {
        data        = <<-EOT
          SERVER_PASS="{{ with nomadVar "nomad/jobs/valheim" }}{{ .server_password }}{{ end }}"
        EOT
        destination = "${NOMAD_SECRETS_DIR}/valheim.env"
        env         = true
      }
      volume_mount {
        volume      = "valheim_data"
        destination = "/opt/valheim"
      }
      volume_mount {
        volume      = "valheim_config"
        destination = "/config"
      }
    }
  }
}
