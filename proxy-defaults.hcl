Kind = "proxy-defaults"
Name = "global"
Config {
  envoy_prometheus_bind_addr = "0.0.0.0:9102"
  envoy_extra_static_clusters_json =<<EOF
{
  "connect_timeout": "3.000s",
  "dns_lookup_family": "V4_ONLY",
  "lb_policy": "ROUND_ROBIN",
  "typed_extension_protocol_options": {
    "envoy.extensions.upstreams.http.v3.HttpProtocolOptions": {
      "@type": "type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions",
      "explicit_http_config": {
        "http2_protocol_options": {}
      }
    }
  },
  "load_assignment": {
    "cluster_name": "tempo-otlp",
    "endpoints": [
      {
        "lb_endpoints": [
          {
            "endpoint": {
              "address": {
                "socket_address": {
                  "address": "tempo.service.consul",
                  "port_value": 4317
                }
              }
            }
          }
        ]
      }
    ]
  },
  "name": "tempo-otlp",
  "type": "STRICT_DNS"
}
EOF
  envoy_tracing_json =<<EOF
{
  "http": {
    "name": "envoy.tracers.opentelemetry",
    "typedConfig": {
      "@type": "type.googleapis.com/envoy.config.trace.v3.OpenTelemetryConfig",
      "grpc_service": {
        "envoy_grpc": {
          "cluster_name": "tempo-otlp"
        }
      }
    }
  }
}
EOF
}