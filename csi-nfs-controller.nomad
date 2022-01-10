job "plugin-nfs-controller" {
  datacenters = ["byb"]

  group "controller" {
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
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 250
        memory = 128
      }
    }
  }
}
