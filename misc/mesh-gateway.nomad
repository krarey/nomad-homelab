job "mesh-gateway" {
  datacenters = ["byb"]
  group "mesh-gateway" {
    network {
      mode = "bridge"
      port "wan" {} // This will be automatically configured by Nomad as the Mesh Gateway WAN port/interface
      port "metrics" {
        to = 9102
      }
    }
    scaling {
      enabled = true
      min     = 1
      max     = 3
      policy {
        check "mesh_gateway_throughput" {
          source = "prometheus"
          # query = "avg(rate(label_join({__name__=~'envoy_tcp_default_.+_downstream_cx_[t,r]x_bytes_total', consul_source_service='mesh-gateway', consul_source_datacenter='pri', envoy_tcp_prefix='mesh_gateway_remote'}, 'metric', ',', '__name__')[1m:])) / 1024"
          query = "sum(nomad_client_allocs_cpu_total_ticks{exported_job='mesh-gateway'}) / sum(nomad_client_allocs_cpu_allocated{exported_job='mesh-gateway'})"
          strategy "threshold" {
            upper_bound = 1
            lower_bound = 0.6
            delta       = 1
          }
          strategy "threshold" {
            upper_bound = 0.3
            lower_bound = 0
            delta       = -1
          }
        }
      }
    }
    service {
      name = "mesh-gateway"
      port = "wan"
      connect {
        gateway {
          mesh {}
        }
      }
      meta {
        metrics_port = NOMAD_HOST_PORT_metrics
        consul-wan-federation = 1 // Optional, tells the Mesh gateway to expose routes to the Consul server nodes for WAN serf encapsulation
      }
      # Optional, apply an advertised WAN address to the mesh gateway service registration.
      # This is the address that mesh gateways in other Consul datacenters will connect to when dialing a service in this DC
      # This could be a direct address, load balancer, etc.
      # tagged_addresses {
      #   wan = "<external address:port>"
      # }
      check {
        name     = "Mesh gateway listening"
        type     = "tcp"
        interval = "10s"
        timeout  = "10s"
        port     = "connect-mesh-mesh-gateway-lan" // Templated by Nomad as connect-mesh-<service>-lan
      }
    }
  }
}
