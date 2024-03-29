# Depending on if the first subnet is a public one or not, the EC2 instance might
# not be able to get a public IP address. Hence, we also attach it to the load balancer.
locals {
  ssh_alternative_port = 2222
  prometheus_password  = var.prometheus_password == null ? random_password.prometheus_password.result : var.prometheus_password
  prometheus_config = {
    "basic_auth_users" : {
      "admin" : bcrypt(local.prometheus_password)
    }
  }
  prometheus_ssl_config = {
    "tls_server_config" : {
      "cert_file" : "/etc/certificate.pem",
      "key_file" : "/etc/private_key.pem"
    }
  }
  sql_exporter_config = {
    "global" : {
      "scrape_timeout_offset" : "500ms",
      "min_interval" : "0s",
      "max_connections" : 3,
      "max_idle_connections" : 3
    },
    "target" : {
      "data_source_name" : "postgres://${local.config.crate_username}:${urlencode(local.cratedb_password)}@${aws_lb.loadbalancer.dns_name}:5432/crate?sslmode=${var.crate.ssl_enable ? "require" : "disable"}",
      "collectors" : ["cratedb_standard"]
    },
    "collector_files" : ["*.collector.yml"]
  }
}

resource "random_password" "prometheus_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

data "cloudinit_config" "config_utilities" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/scripts/cloud-init-utilities.tftpl",
      {
        crate_host            = aws_lb.loadbalancer.dns_name
        crate_user            = local.config.crate_username
        crate_password        = local.cratedb_password
        crate_ssl             = var.crate.ssl_enable
        prometheus_config     = indent(6, yamlencode(var.prometheus_ssl ? merge(local.prometheus_config, local.prometheus_ssl_config) : local.prometheus_config))
        sql_exporter_config   = indent(6, yamlencode(local.sql_exporter_config))
        jmx_targets           = indent(16, yamlencode(formatlist("%s:8080", aws_network_interface.interface[*].private_ip)))
        node_exporter_targets = indent(16, yamlencode(formatlist("%s:9100", aws_network_interface.interface[*].private_ip)))
        ssl_certificate       = base64encode(tls_self_signed_cert.ssl.cert_pem)
        ssl_private_key       = base64encode(tls_private_key.ssl.private_key_pem)
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

  ingress {
    description      = "Prometheus"
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Locust"
    from_port        = 8089
    to_port          = 8089
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

  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.utilities[count.index].id]

  tags = {
    Name = "${local.config.component_name}-if-${count.index}"
  }
}

# Not reusing the AMI from CrateDB nodes, as the architecture can differ (amd64 vs arm64)
data "aws_ami" "amazon_linux_utilities" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami*"]
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
    network_interface_id = aws_network_interface.utilities_interface[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.utility_vm.disk_size_gb
  }

  lifecycle {
    ignore_changes = [user_data, ami]
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

resource "aws_lb_target_group" "prometheus" {
  count = var.enable_utility_vm ? 1 : 0

  name     = "${local.config.component_name}-target-prometheus"
  port     = 9090
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  target_group_arn = aws_lb_target_group.utilities[count.index].arn
  target_id        = aws_instance.utilities[count.index].id
  port             = 22
}

resource "aws_lb_target_group_attachment" "prometheus" {
  count = var.enable_utility_vm ? 1 : 0

  target_group_arn = aws_lb_target_group.prometheus[count.index].arn
  target_id        = aws_instance.utilities[count.index].id
  port             = 9090
}

resource "aws_lb_listener" "utilities" {
  count = var.enable_utility_vm ? 1 : 0

  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = local.ssh_alternative_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.utilities[count.index].arn
  }
}

resource "aws_lb_listener" "prometheus" {
  count = var.enable_utility_vm ? 1 : 0

  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = 9090
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus[count.index].arn
  }
}
