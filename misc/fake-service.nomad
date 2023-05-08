job "fake-service" {
  datacenters = ["byb"]

  group "web" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "fake-web"
      port = 9090
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.fake-web-tls.tls=true",
        "traefik.http.routers.fake-web.middlewares=redirect-https@file"
      ]

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "fake-api"
              local_bind_port  = 9091
            }
          }
        }
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.25.1"
      }

      env {
        LISTEN_ADDR          = "0.0.0.0:9090"
        UPSTREAM_URIS        = "http://127.0.0.1:9091"
        MESSAGE              = "Hello World"
        NAME                 = "web"
        SERVER_TYPE          = "http"
        TIMING_50_PERCENTILE = "30ms"
        TIMING_90_PERCENTILE = "60ms"
        TIMING_99_PERCENTILE = "90ms"
        TIMING_VARIANCE      = 10
        TRACING_ZIPKIN       = "http://tempo.service.consul:9411"
        LOG_LEVEL            = "trace"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }

  group "api" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "fake-api"
      port = 9090

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "fake-currency"
              local_bind_port  = 9091
            }
            upstreams {
              destination_name = "fake-cache"
              local_bind_port  = 9092
            }
            upstreams {
              destination_name = "fake-payments"
              local_bind_port  = 9093
            }
          }
        }
      }
    }

    task "api" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.25.1"
      }

      env {
        LISTEN_ADDR                = "0.0.0.0:9090"
        UPSTREAM_URIS              = "grpc://127.0.0.1:9091, http://127.0.0.1:9092/abc/123123, http://127.0.0.1:9093"
        UPSTREAM_WORKERS           = 2
        MESSAGE                    = "API Response"
        NAME                       = "api"
        SERVER_TYPE                = "http"
        TIMING_50_PERCENTILE       = "20ms"
        TIMING_90_PERCENTILE       = "30ms"
        TIMING_99_PERCENTILE       = "40ms"
        TIMING_VARIANCE            = 10
        HTTP_CLIENT_APPEND_REQUEST = "true"
        TRACING_ZIPKIN             = "http://tempo.service.consul:9411"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }

  group "cache" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "fake-cache"
      port = 9090

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      connect {
        sidecar_service {}
      }
    }

    task "cache" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.25.1"
      }

      env {
        LISTEN_ADDR          = "0.0.0.0:9090"
        MESSAGE              = "Cache Response"
        NAME                 = "cache"
        SERVER_TYPE          = "http"
        TIMING_50_PERCENTILE = "1ms"
        TIMING_90_PERCENTILE = "2ms"
        TIMING_99_PERCENTILE = "3ms"
        TIMING_VARIANCE      = 10
        TRACING_ZIPKIN       = "http://tempo.service.consul:9411"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }

  group "payments" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "fake-payments"
      port = 9090

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "fake-currency"
              local_bind_port  = 9091
            }
          }
        }
      }
    }

    task "payments" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.25.1"
      }

      env {
        LISTEN_ADDR                = "0.0.0.0:9090"
        UPSTREAM_URIS              = "grpc://127.0.0.1:9091"
        MESSAGE                    = "Payments Response"
        NAME                       = "payments"
        SERVER_TYPE                = "http"
        HTTP_CLIENT_APPEND_REQUEST = "true"
        TRACING_ZIPKIN             = "http://tempo.service.consul:9411"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }

  group "currency" {
    network {
      mode = "bridge"
      port "metrics" {
        to = 9102
      }
    }

    service {
      name = "fake-currency"
      port = 9090

      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
      }

      connect {
        sidecar_service {}
      }
    }

    task "currency" {
      driver = "docker"

      config {
        image = "nicholasjackson/fake-service:v0.25.1"
      }

      env {
        LISTEN_ADDR    = "0.0.0.0:9090"
        MESSAGE        = "Currency Response"
        NAME           = "currency"
        SERVER_TYPE    = "grpc"
        ERROR_RATE     = 0.2
        ERROR_CODE     = 14
        ERROR_TYPE     = "http_error"
        TRACING_ZIPKIN = "http://tempo.service.consul:9411"
      }

      resources {
        cpu    = 100
        memory = 16
      }
    }
  }
}
