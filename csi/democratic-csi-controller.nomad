job "democratic-controller" {
  datacenters = ["byb"]
  type        = "service"

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:v1.8.1"

        args = [
          "--csi-version=1.5.0",
          "--csi-name=org.democratic-csi.synology-iscsi",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=controller",
          "--server-socket=/csi-data/csi.sock",
          "--server-address=0.0.0.0",
          "--server-port=9000",
        ]
      }

      csi_plugin {
        id        = "synology-iscsi"
        type      = "controller"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        data        = <<-EOT
          driver: synology-iscsi
          httpConnection:
            protocol: https
            host: foundation.byb.lan
            port: 5001
            username: nomad
            password: "{{ with secret "kv/default/democratic-controller" }}{{ .Data.data.synology_password }}{{ end }}"
            allowInsecure: true
            session: democratic-csi
            serialize: true
          synology:
            volume: /volume1
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

      vault {
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      resources {
        cpu    = 30
        memory = 128
      }
    }
  }
}
