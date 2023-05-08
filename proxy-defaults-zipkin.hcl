Kind = "proxy-defaults"
Name = "global"
Config {
  envoy_prometheus_bind_addr = "0.0.0.0:9102"
  envoy_extra_static_clusters_json =<<-EOT
    {
      "connect_timeout":"3.000s",
      "dns_lookup_family":"V4_ONLY",
      "lb_policy":"ROUND_ROBIN",
      "load_assignment":{
        "cluster_name":"tempo-zipkin",
        "endpoints":[
          {
            "lb_endpoints":[
              {
                "endpoint":{
                  "address":{
                    "socket_address":{
                      "address":"tempo.service.consul",
                      "port_value":9411,
                      "protocol":"TCP"
                    }
                  }
                }
              }
            ]
          }
        ]
      },
      "name":"tempo-zipkin",
      "type":"STRICT_DNS"
    }
  EOT
  envoy_tracing_json = <<-EOT
    {
      "http":{
        "name":"envoy.tracers.zipkin",
        "typedConfig":{
          "@type":"type.googleapis.com/envoy.config.trace.v3.ZipkinConfig",
          "collector_cluster":"tempo-zipkin",
          "collector_endpoint_version":"HTTP_JSON",
          "collector_endpoint":"/api/v2/spans",
          "shared_span_context":false
        }
      }
    }
  EOT
}