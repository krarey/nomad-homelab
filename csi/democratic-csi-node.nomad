job "democratic-node" {
  type = "system"

  group "node" {
    task "node" {
      driver = "docker"

      config {
        image        = "democraticcsi/democratic-csi:v1.8.1"
        network_mode = "host"
        ipc_mode     = "host"
        privileged   = true

        args = [
          "--csi-version=1.5.0",
          "--csi-name=org.democratic-csi.synology-iscsi",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=node",
          "--server-socket=/csi-data/csi.sock",
        ]

        mount {
          type     = "bind"
          target   = "/host"
          source   = "/"
          readonly = false
        }

        mount {
          type     = "bind"
          target   = "/run/udev"
          source   = "/run/udev"
          readonly = true
        }
      }

      csi_plugin {
        id        = "synology-iscsi"
        type      = "node"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"

        data = <<-EOT
          driver: synology-iscsi
          iscsi:
            targetPortal: foundation.byb.lan
            baseiqn: "iqn.2000-01.com.synology:csi."
            lunTemplate:
              type: "BLUN"
            lunSnapshotTemplate:
              is_locked: true
              is_app_consistent: true
            targetTemplate:
              auth_type: 0
              max_sessions: 0
        EOT
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
