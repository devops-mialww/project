output "url" {
  value = "http://127.0.0.1:${var.host_port}"
}

output "image_id" {
  value = docker_image.app.image_id
}
