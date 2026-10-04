# Insecure on purpose: every custom policy must fail here
resource "docker_container" "bad" {
  name         = "bad"
  image        = "fastapi-crud:latest"
  privileged   = true
  user         = "root"
  network_mode = "host"
}
