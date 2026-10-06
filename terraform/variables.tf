variable "image_tag" {
  description = "Tag for the built image; CD passes the commit SHA"
  type        = string
  default     = "local"
}

variable "host_port" {
  description = "Port on 127.0.0.1 that maps to the API"
  type        = number
  default     = 8000
}

variable "memory_mb" {
  description = "Memory limit for the container in MB"
  type        = number
  default     = 256
}
