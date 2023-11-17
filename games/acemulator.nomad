job "acemulator" {
  datacenters = ["x86"]

  vault {
    change_mode   = "signal"
    change_signal = "SIGHUP"
  }

  group "mariadb" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
      port "mysql" {
        to = 3306 # Keeping this open for external management tools
      }
    }

    service {
      name = "mariadb"
      port = 3306
      connect {
        sidecar_service {}
      }
      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }
    }

    // Just going to use host mounts here, the targeted DC only has a single host
    // and my iSCSI CSI storage is slow.
    volume "ace_db" {
      type   = "host"
      source = "ace_db"
    }

    task "mariadb" {
      driver = "docker"
      env {
        MYSQL_USER     = "acedockeruser"
        MYSQL_DATABASE = "ace%"
      }
      config {
        image = "mariadb:10.8.3"
      }
      resources {
        memory = 512
      }
      template {
        data        = <<-EOT
          MYSQL_ROOT_PASSWORD="{{ with secret "kv/default/acemulator" }}{{ .Data.data.mysql_root }}{{ end }}"
          MYSQL_PASSWORD="{{ with secret "kv/default/acemulator" }}{{ .Data.data.mysql_user }}{{ end }}"
        EOT
        destination = "${NOMAD_SECRETS_DIR}/mysql.env"
        env         = true
      }
      volume_mount {
        volume      = "ace_db"
        destination = "/var/lib/mysql"
      }
    }
  }

  group "acemulator" {
    network {
      mode = "bridge"
      port "game1" {
        static = 9000
        to     = 9000
      }
      port "game2" {
        static = 9001
        to     = 9001
      }
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "acemulator"
      port = 9000
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "mariadb"
              local_bind_port  = 3306
            }
          }
        }
      }
      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }
    }

    // This isn't containerized well, so stateful directories are mixed up with containerized app data
    // So we need a bunch of distinct path mounts to underlying storage.
    volume "ace_config" {
      type   = "host"
      source = "ace_config"
    }
    volume "ace_content" {
      type   = "host"
      source = "ace_content"
    }
    volume "ace_dats" {
      type   = "host"
      source = "ace_dats"
    }
    volume "ace_logs" {
      type   = "host"
      source = "ace_logs"
    }

    task "await-mariadb-service" {
      driver = "docker"

      config {
        image   = "busybox:1.35"
        command = "sh"
        args    = ["-c", "echo -n 'Waiting for service'; until nslookup mariadb.service.consul 2>&1 >/dev/null; do echo '.'; sleep 2; done"]
      }

      resources {
        cpu    = 200
        memory = 100
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "acemulator" {
      driver = "docker"
      env {
        ACE_WORLD_NAME                        = "Ecorto"
        ACE_DAT_FILES_DIRECTORY               = "/ace/Dats"
        ACE_SQL_AUTH_DATABASE_NAME            = "ace_auth"
        ACE_SQL_AUTH_DATABASE_HOST            = "localhost"
        ACE_SQL_AUTH_DATABASE_PORT            = 3306
        ACE_SQL_SHARD_DATABASE_NAME           = "ace_shard"
        ACE_SQL_SHARD_DATABASE_HOST           = "localhost"
        ACE_SQL_SHARD_DATABASE_PORT           = 3306
        ACE_SQL_WORLD_DATABASE_NAME           = "ace_world"
        ACE_SQL_WORLD_DATABASE_HOST           = "localhost"
        ACE_SQL_WORLD_DATABASE_PORT           = 3306
        ACE_SQL_INITIALIZE_DATABASES          = true
        ACE_SQL_DOWNLOAD_LATEST_WORLD_RELEASE = true
        ACE_NONINTERACTIVE_CONSOLE            = true
        MYSQL_USER                            = "acedockeruser"
      }
      config {
        image = "acemulator/ace:latest"
      }
      resources {
        memory = 4092
        cpu    = 8600
      }
      template {
        data        = <<-EOT
          MYSQL_PASSWORD="{{ with secret "kv/default/acemulator" }}{{ .Data.data.mysql_user }}{{ end }}"
        EOT
        destination = "${NOMAD_SECRETS_DIR}/mysql.env"
        env         = true
      }
      volume_mount {
        volume      = "ace_config"
        destination = "/ace/Config"
      }
      volume_mount {
        volume      = "ace_content"
        destination = "/ace/Content"
      }
      volume_mount {
        volume      = "ace_dats"
        destination = "/ace/Dats"
      }
      volume_mount {
        volume      = "ace_logs"
        destination = "/ace/Logs"
      }
    }
  }
}
