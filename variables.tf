variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 80
}

variable "network_name" {
  description = "The name of the VPC to use"
  type        = string
  default     = "default"
}
