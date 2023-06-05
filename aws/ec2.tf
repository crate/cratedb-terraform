locals {
  cratedb_password = var.cratedb_password == null ? random_password.cratedb_password.result : var.cratedb_password
}

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

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Cloud Init script for initializing CrateDB
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/scripts/cloud-init-cratedb-${var.cratedb_tar_download_url == null ? "rpm" : "tar"}.tftpl",
      {
        crate_download_url    = var.cratedb_tar_download_url
        crate_user            = local.config.crate_username
        crate_pass            = local.cratedb_password
        crate_heap_size       = var.crate.heap_size_gb
        crate_cluster_name    = var.crate.cluster_name
        crate_cluster_size    = var.crate.cluster_size
        crate_nodes_ips       = indent(12, yamlencode(aws_network_interface.interface[*].private_ip))
        crate_ssl_enable      = var.crate.ssl_enable
        crate_ssl_certificate = base64encode(tls_self_signed_cert.ssl.cert_pem)
        crate_ssl_private_key = base64encode(tls_private_key.ssl.private_key_pem)
      }
    )
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

  ingress {
    description      = "CrateDB-JMX"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "node_exporter"
    from_port        = 9100
    to_port          = 9100
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.ssh_access ? ["0.0.0.0/0"] : []
    ipv6_cidr_blocks = var.ssh_access ? ["::/0"] : []
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami*"]
  }

  filter {
    name   = "architecture"
    values = [var.instance_architecture]
  }

  owners = ["amazon"]
}

resource "aws_network_interface" "interface" {
  count = var.crate.cluster_size

  subnet_id       = element(var.subnet_ids, count.index)
  security_groups = [aws_security_group.cratedb.id]

  tags = {
    Name = "${local.config.component_name}-if-${count.index}"
  }
}

resource "aws_instance" "cratedb_node" {
  count = var.crate.cluster_size

  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = var.instance_type
  key_name             = var.ssh_keypair
  availability_zone    = element(var.availability_zones, count.index)
  user_data            = data.cloudinit_config.config.rendered
  monitoring           = var.enable_utility_vm
  iam_instance_profile = var.instance_profile

  network_interface {
    network_interface_id = aws_network_interface.interface[count.index].id
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
    Name = "${local.config.component_name}-node-${count.index}"
  }
}

resource "aws_lb_target_group_attachment" "http" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.cratedb_node[count.index].private_ip
}

resource "aws_lb_target_group_attachment" "postgresql" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.postgresql.arn
  target_id        = aws_instance.cratedb_node[count.index].private_ip
}

resource "aws_lb_target_group_attachment" "jmx" {
  count = var.crate.cluster_size

  target_group_arn = aws_lb_target_group.jmx.arn
  target_id        = aws_instance.cratedb_node[count.index].private_ip
}
