job "echo" {
  datacenters = ["byb"]

  group "http-server" {
    count = 2
    network {
      mode = "bridge"
    }

    service {
      name = "echo"
      port = 8080

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.echo-http.rule=Path(`/`)"
      ]

      connect {
        sidecar_service {}
      }
    }

    task "http-https-echo" {
      driver = "docker"
      config {
        image = "mendhak/http-https-echo:20"
      }
    }
  }
}
