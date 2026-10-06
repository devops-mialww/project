terraform {
  required_version = ">= 1.9"

  # CD passes -backend-config="path=..." so the state survives the runner's checkout
  backend "local" {}

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }
}

provider "docker" {}

# A new tag changes the name, which forces a rebuild from the repo root
resource "docker_image" "app" {
  name         = "fastapi-crud:${var.image_tag}"
  keep_locally = true

  build {
    context = "${path.module}/.."
  }
}

# The root filesystem is read-only, so SQLite needs its own writable volume
resource "docker_volume" "data" {
  name = "fastapi-crud-data"
}

resource "docker_container" "app" {
  name    = "fastapi-crud"
  image   = docker_image.app.image_id
  restart = "unless-stopped"

  # memory_swap equal to memory means no swap; left unset, Docker fills in 2x and every plan shows drift
  user          = "31337:31337"
  read_only     = true
  memory        = var.memory_mb
  memory_swap   = var.memory_mb
  security_opts = ["no-new-privileges:true"]

  capabilities {
    drop = ["ALL"]
  }

  ports {
    internal = 8000
    external = var.host_port
    ip       = "127.0.0.1"
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/app/data"
  }
}
