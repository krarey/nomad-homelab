job "code-server" {
  datacenters = ["x86"]

  group "server" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    volume "data" {
      type            = "csi"
      source          = "code-server"
      read_only       = false
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    service {
      name = "code-server"
      port = 8080
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.code-server-tls.tls=true",
        "traefik.http.routers.code-server.middlewares=redirect-https@file"
      ]

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      check {
        name     = "Code-Server HTTP Probe"
        expose   = true
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "4s"
      }

      connect {
        sidecar_service {}
      }
    }

    task "storage-init" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "busybox:latest"
        command = "/bin/sh"
        args = [
          "-c",
          "chown -R 1000:1000 /home/coder"
        ]
      }

      volume_mount {
        volume      = "data"
        destination = "/home/coder"
        read_only   = false
      }
    }

    task "code-server" {
      driver = "docker"

      config {
        image          = "codercom/code-server:4.11.0"
        auth_soft_fail = true
      }

      volume_mount {
        volume      = "data"
        destination = "/home/coder"
        read_only   = false
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/code-server.env"
        env         = true
        data        = "{{ with secret \"kv/code-server\" }}PASSWORD={{ .Data.data.password }}{{ end }}"
      }

      vault {
        policies    = ["code-server"]
        change_mode = "noop"
      }

      resources {
        cpu    = 1200
        memory = 1024
      }
    }
  }
}
