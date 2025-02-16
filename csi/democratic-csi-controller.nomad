job "democratic-csi-controller" {
  datacenters = ["byb"]
  type        = "service"

  group "nfs" {
    count = 2
    task "plugin" {
      driver = "podman"

      config {
        image = "ghcr.io/democratic-csi/democratic-csi:v1.9.3"

        args = [
          "--csi-version=1.9.0",
          "--csi-name=org.democratic-csi.freenas-api-nfs",
          "--driver-config-file=${NOMAD_SECRETS_DIR}/driver-config-file.yaml",
          "--csi-mode=controller",
          "--server-socket=/csi-data/csi.sock",
          "--server-address=0.0.0.0",
          "--server-port=9000",
        ]
      }

      csi_plugin {
        id        = "truenas-nfs"
        type      = "controller"
        mount_dir = "/csi-data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/driver-config-file.yaml"
        data        = <<-EOT
          driver: freenas-api-nfs
          httpConnection:
            protocol: https
            host: truenas.byb.lan
            port: 443
            apiKey: {{ with nomadVar "nomad/jobs/democratic-csi-controller" }}{{ .truenas_api_key }}{{ end }}
            allowInsecure: true
            apiVersion: 2
          zfs:
            datasetParentName: default/nomad/byb/volumes
            detachedSnapshotsDatasetParentName: default/nomad/byb/snapshots
            datasetEnableQuotas: true
            datasetEnableReservation: false
            datasetPermissionsMode: "0777"
            datasetPermissionsUser: 0
            datasetPermissionsGroup: 0
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
