job "consul-gw" {
  datacenters = ["gcp"]
  type        = "system"
  group "mesh" {
    network {
      mode = "host"
      port "mesh" {
        static = 8443
      }
    }
    service {
      name = "mesh-gateway"
      port = "mesh"

      connect {
        gateway {
          mesh {}
          proxy {}
        }
      }
    }
  }
  group "terminating" {
    network {
      mode = "bridge"
    }
    service {
      name = "terminating-gateway"
      connect {
        gateway {
          terminating {
            service {
              name = "external-svc"
            }
          }
        }
      }
    }
  }
  group "ingress" {
    network {
      port "api" {
        static = 8080
      }
    }

    service {
      name = "ingress-gateway"
      port = "api"

      connect {
        gateway {
          ingress {
            listener {
              port     = 8080
              protocol = "http"
              service {
                name  = "web"
                hosts = ["*"]
              }
            }
          }
        }
      }
    }
  }
}

