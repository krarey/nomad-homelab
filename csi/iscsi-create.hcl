type         = "csi"
id           = "forgejo-data"
name         = "forgejo-data"
plugin_id    = "truenas-iscsi"
capacity_min = "1GiB"
capacity_max = "1GiB"

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "ext4"
  mount_flags = ["noatime"]
}
