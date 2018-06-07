variable depends_on {
  default = [],
  type = "list"
}

variable "region" {
  default = "eu-west-3"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "keyname" {}

variable "keypair" {}

variable "owner" {}

variable "env" {
  default = "dev"
}

