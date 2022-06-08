job "democratic-node" {
  datacenters = ["byb"]
  type        = "system"

  group "node" {
    task "node" {
      driver = "docker"

      config {
        image        = "democraticcsi/democratic-csi:v1.6.3"
        network_mode = "host"
        ipc_mode     = "host"
        privileged   = true

        args = [
          "--csi-version=1.2.0",
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
      }

      csi_plugin {
        id        = "synology-iscsi"
        type      = "node"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"

        data = <<EOH
driver: synology-iscsi
httpConnection:
  protocol: https
  host: foundation.byb.lan
  port: 5001
  username: nomad
  password: "{{ with secret "kv/csi_iscsi" }}{{ .Data.data.password }}{{ end }}"
  allowInsecure: true
  session: democratic-csi
  serialize: true
synology:
  volume: /volume1
iscsi:
  targetPortal: foundation.byb.lan
  interface: ""
  baseiqn: "iqn.2000-01.com.synology:csi."
  # MUST ensure uniqueness
  # full iqn limit is 223 bytes, plan accordingly
  namePrefix: ""
  nameSuffix: ""
  lunTemplate:
    type: "BLUN"
  lunSnapshotTemplate:
    is_locked: true
    # https://kb.synology.com/en-me/DSM/tutorial/What_is_file_system_consistent_snapshot
    is_app_consistent: true
  targetTemplate:
    auth_type: 0
    max_sessions: 0
EOH
      }

      vault {
        policies      = ["csi-iscsi"]
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }

      resources {
        cpu    = 30
        memory = 50
      }
    }
  }
}
