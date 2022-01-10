job "plugin-smb-controller" {
  datacenters = ["byb"]

  group "controller" {
    task "plugin" {
      driver = "docker"

      config {
        image      = "mcr.microsoft.com/k8s/csi/smb-csi:v1.4.0"
        privileged = true
        args = [
          "--endpoint=unix://csi/csi.sock",
          "--v=5",
        ]
      }

      csi_plugin {
        id        = "smb"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 200
      }
    }
  }
}
