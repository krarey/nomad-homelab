id           = "vault-safe[2]"
name         = "vault-safe[2]"
type         = "csi"
plugin_id    = "nfs"

capability {
  access_mode     = "multi-node-single-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "nfs"
  mount_flags = ["nfsvers=4.1", "soft"]
}

parameters {
  server = "foundation.byb.lan"
  share  = "/volume1/containers"
}
