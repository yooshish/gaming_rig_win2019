variable "tags" {
  type = map
}

variable rig_instance_size {}
variable rig_disk_size {}

variable my_ip {}

## AWS SECRETS
variable "aws_access_key" {}
variable "aws_secret_key" {}