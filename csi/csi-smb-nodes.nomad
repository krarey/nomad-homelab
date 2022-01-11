job "plugin-smb-nodes" {
  datacenters = ["byb"]
  type        = "system"

  group "nodes" {
    task "plugin" {
      driver = "docker"

      config {
        image      = "mcr.microsoft.com/k8s/csi/smb-csi:v1.4.0"
        privileged = true

        args = [
          "--endpoint=unix://csi/csi.sock",
          "--v=5",
          "--nodeid=${node.unique.id}"
        ]
      }

      csi_plugin {
        id        = "smb"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 200
      }
    }
  }
}
