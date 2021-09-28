terraform {
  required_version = "~> 1"

  required_providers {
    aws = {
      source = "aws"
      version = "~> 3.0"
    }

    template = {
      source = "template"
      version = "~> 2.2"
    }

    random = {
      source = "random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
    config = {
        project_name = var.config.project_name
        environment = var.config.environment
        component_name = "${var.config.project_name}-${var.config.environment}"
        crate_username = "admin"
    }
}

resource "random_password" "cratedb_password" {
  length = 16
  special = true
  override_special = "_%@"
}

# Cloud Init script for initializing CrateDB
data "template_file" "crate_provisioning" {
  template = file("${path.module}/scripts/cloud-init-cratedb.tpl")

  vars = {
    crate_user = local.config.crate_username
    crate_pass = random_password.cratedb_password.result
    crate_heap_size = var.crate.heap_size_gb
    crate_cluster_name  = var.crate.cluster_name
    crate_cluster_size = var.crate.cluster_size
    crate_nodes_ips = indent(12, yamlencode(aws_network_interface.interface.*.private_ip))
  }
}

data "template_cloudinit_config" "config" {
  gzip = true
  base64_encode = true

  part {
    filename = "init.cfg"
    content_type = "text/cloud-config"
    content = data.template_file.crate_provisioning.rendered
  }
}

resource "aws_security_group" "cratedb_security_group" {
  name = "${local.config.component_name}-sg"
  description = "Allow inbound CrateDB traffic"
  vpc_id  = var.vpc_id

  ingress {
      description = "CrateDB-HTTP"
      from_port = 4200
      to_port = 4200
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "CrateDB-PostgreSQL"
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "CrateDB-Transport"
    from_port = 4300
    to_port = 4300
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    tags = {
      Environment = local.config.environment
      Owner = var.config.owner
      Team = var.config.team
    }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["*ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_lb" "loadbalancer" {
  name = "${local.config.component_name}-lb"
  internal = false
  load_balancer_type = "network"
  subnets = var.subnet_ids

  tags = {
    Environment = local.config.environment
    Owner = var.config.owner
    Team = var.config.team
  }
}

resource "aws_network_interface" "interface" {
  count = var.crate.cluster_size

  subnet_id = element(var.subnet_ids, count.index)
  security_groups = [aws_security_group.cratedb_security_group.id]

  tags = {
    Name = "${local.config.component_name}-if-${count.index}"
    Environment = local.config.environment
    Owner = var.config.owner
    Team = var.config.team
  }
}

resource "aws_instance" "cratedb_node" {
  count = var.crate.cluster_size

  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.xlarge"
  key_name = var.ssh_keypair
  availability_zone = element(var.availability_zones, count.index)
  user_data = data.template_cloudinit_config.config.rendered

  network_interface {
    network_interface_id = element(aws_network_interface.interface.*.id, count.index)
    device_index = 0
  }

  root_block_device {
    volume_size = 50
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = var.disk_size_gb
  }

  tags = {
    Name = "${local.config.component_name}-node-${count.index}"
    Environment = local.config.environment
    Owner = var.config.owner
    Team = var.config.team
  }
}

resource "aws_lb_target_group" "http" {
  name = "${local.config.component_name}-target-HTTP"
  port = 4200
  protocol = "TCP"
  target_type = "ip"
  vpc_id = var.vpc_id

  tags = {
    Environment = local.config.environment
    Owner = var.config.owner
    Team = var.config.team
  }
}

resource "aws_lb_target_group" "postgresql" {
  name = "${local.config.component_name}-PostgreSQL"
  port = 5432
  protocol = "TCP"
  target_type = "ip"
  vpc_id = var.vpc_id

  tags = {
    Environment = local.config.environment
    Owner = var.config.owner
    Team = var.config.team
  }
}

resource "aws_lb_target_group_attachment" "http" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.http.arn
  target_id = element(aws_instance.cratedb_node.*.private_ip, count.index)
}

resource "aws_lb_target_group_attachment" "postgresql" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.postgresql.arn
  target_id = element(aws_instance.cratedb_node.*.private_ip, count.index)
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port = 4200
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "postgresql" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port = 5432
  protocol = "TCP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.postgresql.arn
  }
}
