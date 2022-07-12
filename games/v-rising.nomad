job "v-rising" {
  datacenters = ["x86"]

  group "v-rising" {
    network {
      mode = "bridge"
      port "game1" {
        static = 9876
        to     = 9876
      }
      port "game2" {
        static = 9877
        to     = 9877
      }
    }

    // Using host mounts, this DC only has one host that has fast local storage
    // My iSCSI CSI storage is slow/unreliable at the moment.
    volume "vrising_server" {
      type   = "host"
      source = "vrising_server"
    }

    volume "vrising_world" {
      type   = "host"
      source = "vrising_world"
    }

    task "vrising-server" {
      driver = "docker"
      env {
        TZ         = "America/New_York"
        SERVERNAME = "Portrait-of-a-V-on-Fire"
      }
      config {
        image = "docker.io/trueosiris/vrising:1.9"
      }
      resources {
        cpu    = 8000
        memory = 6144
      }
      volume_mount {
        volume      = "vrising_server"
        destination = "/mnt/vrising/server"
      }
      volume_mount {
        volume      = "vrising_world"
        destination = "/mnt/vrising/persistentdata"
      }
    }
  }
}
