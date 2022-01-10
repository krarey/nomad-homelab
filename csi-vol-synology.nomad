id              = "synology"
name            = "synology"
type            = "csi"
plugin_id       = "nfs"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type = "nfs"
  mount_flags = ["nfsvers=4.1"]
}

context {
  server = "foundation.byb.lan"
  share = "/volume1/containers"
}