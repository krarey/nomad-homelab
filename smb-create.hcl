id           = "smb-dynamic"
name         = "smb-dynamic"
type         = "csi"
plugin_id    = "smb"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "cifs"
  mount_flags = ["vers=3.0"]
}

parameters {
  source = "//foundation.byb.lan/containers"
}

secrets {
  username = "nomad"
  password = "..."
}
