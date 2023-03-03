job "waypoint-server" {
  datacenters = ["x86"]
  group "waypoint-server" {
    network {
      mode = "host"
      port "server" {
        static = 9701
      }
      port "ui" {
        static = 9702
      }
    }
    service {
      name     = "waypoint-ui"
      port     = "ui"
      provider = "consul"
      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=false",
        "traefik.http.routers.waypoint-ui-tls.tls=true",
        "traefik.http.routers.waypoint-ui.middlewares=redirect-https@file",
        "traefik.http.services.waypoint-ui.loadbalancer.server.scheme=https"
      ]
    }
    service {
      name     = "waypoint-server"
      port     = "server"
      provider = "consul"
      tags     = ["waypoint"]
    }

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
        memory = 600
      }
      volume_mount {
        volume      = "waypoint-server"
        destination = "/data"
      }
    }

    task "server" {
      driver = "docker"
      config {
        image          = "hashicorp/waypoint:0.11.0"
        auth_soft_fail = false
        args = [
          "server",
          "run", "-accept-tos", "-vv",
          "-db=/data/data.db",
          "-listen-grpc=0.0.0.0:9701",
          "-listen-http=0.0.0.0:9702"
        ]
        ports = ["server", "ui"]
      }
      env {
        PORT = "9701"
      }
      resources {
        cpu    = 200
        memory = 600
      }
      volume_mount {
        volume      = "waypoint-server"
        destination = "/data"
      }
    }

    volume "waypoint-server" {
      type   = "host"
      source = "waypoint_server"
    }
  }
}
