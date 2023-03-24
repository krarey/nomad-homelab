job "boundary-worker" {
  datacenters = ["byb"]
  group "worker" {
    count = 1
    network {
      mode = "bridge"
      port "boundary-metrics" {}
    }
    service {
      name = "boundary-hcp-worker"
      port = "boundary-metrics"
      check {
        name     = "Boundary Worker Alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "4s"
      }
      # Let our connect sidecar scrape config pick up boundary worker metrics, too
      meta {
        metrics_port = NOMAD_HOST_PORT_boundary_metrics
      }
    }
    # I don't really feel like carving out iSCSI volumes for this,
    # I'll just re-authorize the workers if it loses state for now.
    ephemeral_disk {
      sticky  = true
      migrate = true
      size    = 110
    }
    task "hcp-worker" {
      driver = "docker"
      config {
        image   = "hashicorp/boundary-worker-hcp:latest"
        command = "boundary-worker"
        args = [
          "server",
          "-config",
          "${NOMAD_TASK_DIR}/boundary.hcl"
        ]
      }
      resources {
        cpu    = 500
        memory = 128
      }
      template {
        destination = "${NOMAD_TASK_DIR}/boundary.hcl"
        data        = <<-EOT
          disable_mlock = true

          hcp_boundary_cluster_id = "{{ with nomadVar "nomad/jobs/boundary-worker" }}{{ .boundary_cluster_id }}{{ end }}"

          # This is an HCP worker, and thus supports multihop via tunneling.
          # I don't intend to expose this to ingress traffic, just egress to my internal targets.
          # Therefore, bind the proxy listener to loopback.
          listener "tcp" {
            address = "127.0.0.1:9202"
            purpose = "proxy"
          }

          listener "tcp" {
            address     = "0.0.0.0:{{ env "NOMAD_PORT_boundary_metrics" }}"
            purpose     = "ops"
            tls_disable = true
          }

          worker {
            # Store PKI credentials in the ephemeral disk.
            # Makes a best effort to retain worker authorization across restarts/deployments.
            auth_storage_path = "{{ env "NOMAD_ALLOC_DIR" }}/data"
            tags {
              type    = ["hosted-worker", "private"]
              network = ["home"]
            }
          }
        EOT
      }
    }
  }
}
