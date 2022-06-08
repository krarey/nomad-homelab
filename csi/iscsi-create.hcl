type         = "csi"
id           = "prometheus-iscsi"
name         = "prometheus-iscsi"
plugin_id    = "synology-iscsi"
capacity_min = "10GiB"
capacity_max = "10GiB"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["noatime"]
}
