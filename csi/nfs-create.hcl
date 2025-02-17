type         = "csi"
id           = "756873D1-1AE5-474B-8C00-20AB4DBBCB70"
name         = "forgejo-repositories"
plugin_id    = "truenas-nfs"
capacity_min = "1TiB"
capacity_max = "1TiB"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  mount_flags = [
    "noatime",
    "nfsvers=4",
    "hard"
    ]
}
