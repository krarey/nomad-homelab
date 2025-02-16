job "democratic-csi-node" {
  type = "system"

  group "nfs" {
    task "plugin" {
      driver = "podman"

      config {
        image        = "ghcr.io/democratic-csi/democratic-csi:v1.9.3"
        network_mode = "host"
        privileged   = true

        cap_add = [ "SYS_ADMIN" ]

        args = [
          "--csi-version=1.9.0",
          "--csi-name=org.democratic-csi.freenas-api-nfs",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--csi-mode=node",
          "--server-socket=/csi-data/csi.sock",
        ]

        volumes = [
          "/:/host",
          "/run/udev:/run/udev:ro",
        ]
      }

      csi_plugin {
        id        = "truenas-nfs"
        type      = "node"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"

        data = <<-EOT
          driver: freenas-api-nfs
          nfs:
            shareHost: truenas.byb.lan
            shareAlldirs: false
            shareAllowedHosts: []
            shareAllowedNetworks: []
            shareMaprootUser: root
            shareMaprootGroup: root
            shareMapallUser: ""
            shareMapallGroup: ""
        EOT
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
  # TODO: Add iSCSI controller group
}
