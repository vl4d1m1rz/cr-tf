provider "aws" {
  region = "${var.region}"
}

module "vpc_one" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.env}-vpc-1"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-3a"]
  public_subnets  = ["10.0.1.0/24"]

  tags = {
    Name        = "${var.env}-vpc-1"
    Owner       = "${var.owner}"
    Terraform   = "true"
    Environment = "${var.env}"
  }
}

module "vpc_two" {
  source = "terraform-aws-modules/vpc/aws"
  name = "${var.env}-vpc-2"
  cidr = "10.1.0.0/16"
  azs             = ["eu-west-3b"]
  public_subnets  = ["10.1.1.0/24"]
  tags = {
    Name        = "${var.env}-vpc-2"
    Owner       = "${var.owner}"
    Terraform   = "true"
    Environment = "${var.env}"
  }
}

module "sg_one" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "${var.env}-sg-1"
  description = "Security group"
  vpc_id      = "${module.vpc_one.vpc_id}"
  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "all-icmp"
      cidr_blocks = "10.1.0.0/16"
    },
  ]
  egress_with_cidr_blocks = [
    {
      rule = "all-all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "sg_two" {
  source = "terraform-aws-modules/security-group/aws"
  name        = "${var.env}-sg-2"
  description = "Security group"
  vpc_id      = "${module.vpc_two.vpc_id}"

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "all-icmp"
      cidr_blocks = "10.0.0.0/16"
    },
  ]
  egress_with_cidr_blocks = [
    {
      rule = "all-all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
  owners = ["099720109477"]
}

module "node_one" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "node-1"
  instance_count              = 1
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.keyname}"
  monitoring                  = false
  vpc_security_group_ids      = ["${module.sg_one.this_security_group_id}"]
  subnet_id                   = "${module.vpc_one.public_subnets[0]}"
  associate_public_ip_address = true
  tags = {
    Terraform = "true"
    Environment = "${var.env}"
  }
}

module "node_two" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  name                        = "node-2"
  instance_count              = 1
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${var.keyname}"
  monitoring                  = false
  vpc_security_group_ids      = ["${module.sg_two.this_security_group_id}"]
  subnet_id                   = "${module.vpc_two.public_subnets[0]}"
  associate_public_ip_address = true

  tags = {
    Terraform = "true"
    Environment = "${var.env}"
  }
}

module "vpc_peering" {
  source           = "../modules/terraform-aws-vpc-peering"
  namespace        = "cr"
  stage            = "${var.env}"
  name             = "vova"
  requestor_vpc_id = "${module.vpc_one.vpc_id}"
  acceptor_vpc_id  = "${module.vpc_two.vpc_id}"
  auto_accept      = true
  acceptor_allow_remote_vpc_dns_resolution = false
  requestor_allow_remote_vpc_dns_resolution = false
}

resource "null_resource" "ping_one_two" {

  provisioner "file" {
    source      = "files/ping.sh"
    destination = "/tmp/ping.sh"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file(var.keypair)}"
    host        = "${module.node_one.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ping.sh",
      "/tmp/ping.sh ${module.node_two.private_ip[0]}",
    ]
  }
}

resource "null_resource" "ping_two_one" {

  provisioner "file" {
    source      = "files/ping.sh"
    destination = "/tmp/ping.sh"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = "${file(var.keypair)}"
    host        = "${module.node_two.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ping.sh",
      "/tmp/ping.sh ${module.node_one.private_ip[0]}",
    ]
  }
}