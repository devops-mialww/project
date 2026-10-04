# Every custom policy must pass here
resource "docker_container" "good" {
  name         = "good"
  image        = "fastapi-crud:latest"
  user         = "31337:31337"
  read_only    = true
  memory       = 256
  security_opts = ["no-new-privileges:true"]

  capabilities {
    drop = ["ALL"]
  }
}
