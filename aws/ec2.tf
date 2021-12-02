resource "random_password" "cratedb_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "ssl" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ssl" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.ssl.private_key_pem

  # Set to two years. If the number is too high, there appears to be an overflow resulting in a date in the past
  validity_period_hours = 17532

  subject {
    organization = var.config.team
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Cloud Init script for initializing CrateDB
data "template_file" "crate_provisioning" {
  template = file("${path.module}/scripts/cloud-init-cratedb.tpl")

  vars = {
    crate_user            = local.config.crate_username
    crate_pass            = random_password.cratedb_password.result
    crate_heap_size       = var.crate.heap_size_gb
    crate_cluster_name    = var.crate.cluster_name
    crate_cluster_size    = var.crate.cluster_size
    crate_nodes_ips       = indent(12, yamlencode(aws_network_interface.interface.*.private_ip))
    crate_ssl_enable      = var.crate.ssl_enable
    crate_ssl_certificate = base64encode(tls_self_signed_cert.ssl.cert_pem)
    crate_ssl_private_key = base64encode(tls_private_key.ssl.private_key_pem)
  }
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.crate_provisioning.rendered
  }
}

resource "aws_security_group" "cratedb" {
  name        = "${local.config.component_name}-sg"
  description = "Allow inbound CrateDB traffic"
  vpc_id      = var.vpc_id

  ingress {
    description      = "CrateDB-HTTP"
    from_port        = 4200
    to_port          = 4200
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "CrateDB-PostgreSQL"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "CrateDB-Transport"
    from_port        = 4300
    to_port          = 4300
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

  tags = {
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_security_group_rule" "ssh" {
  count = var.ssh_access ? 1 : 0

  security_group_id = aws_security_group.cratedb.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  owners = ["amazon"]
}

resource "aws_network_interface" "interface" {
  count = var.crate.cluster_size

  subnet_id       = element(var.subnet_ids, count.index)
  security_groups = [aws_security_group.cratedb.id]

  tags = {
    Name        = "${local.config.component_name}-if-${count.index}"
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_instance" "cratedb_node" {
  count = var.crate.cluster_size

  ami               = data.aws_ami.amazon_linux.id
  instance_type     = var.instance_type
  key_name          = var.ssh_keypair
  availability_zone = element(var.availability_zones, count.index)
  user_data         = data.template_cloudinit_config.config.rendered

  network_interface {
    network_interface_id = element(aws_network_interface.interface.*.id, count.index)
    device_index         = 0
  }

  root_block_device {
    volume_size = 50
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = var.disk_size_gb
    volume_type = var.disk_type
    iops        = var.disk_iops
    throughput  = var.disk_throughput
  }

  lifecycle {
    ignore_changes = [user_data]
  }

  tags = {
    Name        = "${local.config.component_name}-node-${count.index}"
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_lb_target_group_attachment" "http" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = element(aws_instance.cratedb_node.*.private_ip, count.index)
}

resource "aws_lb_target_group_attachment" "postgresql" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.postgresql.arn
  target_id        = element(aws_instance.cratedb_node.*.private_ip, count.index)
}
