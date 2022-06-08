job "democratic-controller" {
  datacenters = ["byb"]
  type        = "service"

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "democraticcsi/democratic-csi:v1.6.3"

        args = [
          "--csi-version=1.2.0",
          "--csi-name=org.democratic-csi.synology-iscsi",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--log-level=debug",
          "--csi-mode=controller",
          "--server-socket=/csi-data/csi.sock",
          "--server-address=0.0.0.0",
          "--server-port=9000",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "synology-iscsi"
        type      = "controller"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        data        = <<EOH
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
  # choose the proper volume for your system
  volume: /volume1
iscsi:
  targetPortal: foundation.byb.lan
  targetPortals: [] # [ "server[:port]", "server[:port]", ... ]
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
