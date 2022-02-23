# Depending on if the first subnet is a public one or not, the EC2 instance might
# not be able to get a public IP address. Hence, we also attach it to the load balancer
locals {
  ssh_alternative_port = 2222
}

data "cloudinit_config" "config_utilities" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/scripts/cloud-init-utilities.tftpl",
      {
        crate_host : aws_lb.loadbalancer.dns_name,
        crate_user : local.config.crate_username,
        crate_password : random_password.cratedb_password.result
      }
    )
  }
}

resource "aws_security_group" "utilities" {
  name        = "${local.config.component_name}-util-sg"
  description = "Allow inbound SSH traffic"
  vpc_id      = var.vpc_id
  count       = var.enable_utility_vm ? 1 : 0

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_network_interface" "utilities_interface" {
  count = var.enable_utility_vm ? 1 : 0

  subnet_id       = element(var.subnet_ids, count.index)
  security_groups = [element(aws_security_group.utilities.*.id, count.index)]

  tags = {
    Name = "${local.config.component_name}-if-${count.index}"
  }
}

# Not reusing the AMI from CrateDB nodes, as the architecture can differ (amd64 vs arm64)
data "aws_ami" "amazon_linux_utilities" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = [var.utility_vm.instance_architecture]
  }

  owners = ["amazon"]
}

resource "aws_instance" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  ami               = data.aws_ami.amazon_linux_utilities.id
  instance_type     = var.utility_vm.instance_type
  key_name          = var.ssh_keypair
  availability_zone = element(var.availability_zones, count.index)
  user_data         = data.cloudinit_config.config_utilities.rendered

  network_interface {
    network_interface_id = element(aws_network_interface.utilities_interface.*.id, count.index)
    device_index         = 0
  }

  root_block_device {
    volume_size = 50
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = var.utility_vm.disk_size_gb
    volume_type = var.utility_vm.disk_type
  }

  lifecycle {
    ignore_changes = [user_data]
  }

  tags = {
    Name = "${local.config.component_name}-utilities"
  }
}

resource "aws_lb_target_group" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  name     = "${local.config.component_name}-target-utilities"
  port     = 22
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  target_group_arn = element(aws_lb_target_group.utilities.*.arn, count.index)
  target_id        = element(aws_instance.utilities.*.id, count.index)
  port             = 22
}

resource "aws_lb_listener" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = local.ssh_alternative_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = element(aws_lb_target_group.utilities.*.arn, count.index)
  }
}
