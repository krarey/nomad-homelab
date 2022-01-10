job "plugin-nfs-nodes" {
  datacenters = ["byb"]
  type        = "system"

  group "nodes" {
    task "plugin" {
      driver = "docker"

      config {
        image      = "mcr.microsoft.com/k8s/csi/nfs-csi:v3.0.0"
        privileged = true

        args = [
          "--endpoint=unix://csi/csi.sock",
          "--v=5",
          "--nodeid=${node.unique.id}"
        ]
      }

      csi_plugin {
        id        = "nfs"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 250
        memory = 128
      }
    }
  }
}
