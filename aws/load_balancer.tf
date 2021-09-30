resource "aws_lb" "loadbalancer" {
  name               = "${local.config.component_name}-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  tags = {
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_lb_target_group" "http" {
  name        = "${local.config.component_name}-target-HTTP"
  port        = 4200
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  tags = {
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_lb_target_group" "postgresql" {
  name        = "${local.config.component_name}-PostgreSQL"
  port        = 5432
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  tags = {
    Environment = local.config.environment
    Owner       = var.config.owner
    Team        = var.config.team
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = 4200
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "postgresql" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = 5432
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.postgresql.arn
  }
}
