resource "aws_ecs_cluster" "main" {
  name    = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
  setting {
    name = "containerInsights"
    value = "enabled"
  }
  tags    = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))
}

resource "aws_lb" "main" {
  name               = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
  load_balancer_type = "application"
  internal           = true
  subnets            = data.terraform_remote_state.main.outputs.private_subnet_id.*
  security_groups    = [data.terraform_remote_state.main.outputs.sg_public_web_lb]
  idle_timeout       = 20

  access_logs {
    bucket = data.terraform_remote_state.main.outputs.bucket_name_lb_accesslog_bucket
    prefix = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
    enabled = true
  }

  tags    = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))

}

resource "aws_lb_target_group" "main" {
  name                = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
  vpc_id               = data.terraform_remote_state.main.outputs.vpc_id
  port                 = "80"
  protocol             = "HTTP"
  deregistration_delay = "90"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = "5"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    matcher             = "200" 
  }

  tags    = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))
}

resource "aws_lb_listener" "main_80" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "tls_private_key" "main" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "main" {
  key_name   = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
  public_key = tls_private_key.main.public_key_openssh
}


resource "aws_secretsmanager_secret" "main" {
  name                    = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])
  recovery_window_in_days = 0
  description             = "[Terraform] SSH root key for '${aws_ecs_cluster.main.name}'' cluster"
  tags                    = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_string = jsonencode(merge(map("keypair", tls_private_key.main.private_key_pem)))
}

resource "aws_spot_fleet_request" "main" {
  iam_fleet_role    = data.aws_iam_role.spot_fleet.arn
  target_capacity   = 2
  valid_until       = timeadd(timestamp(), "140m")
  load_balancers    = [aws_lb.main.arn]
  target_group_arns = [aws_lb_target_group.main.arn]

  launch_specification {
    instance_type          = "t2.small"
    ami                    = data.aws_ami.main.image_id
    key_name               = aws_key_pair.main.key_name
    vpc_security_group_ids = [ 
      data.terraform_remote_state.bastion.outputs.ssh_sg_id,
      data.terraform_remote_state.main.outputs.sg_access_to_internet
    ]
    #availability_zone = join(", ", data.terraform_remote_state.main.outputs.availability_zones.*)
    subnet_id         = join(", ", data.terraform_remote_state.main.outputs.private_subnet_id.*)
    tags              = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))
  }

  launch_specification {
    instance_type          = "t2.medium"
    ami                    = data.aws_ami.main.image_id
    key_name               = aws_key_pair.main.key_name
    vpc_security_group_ids = [ 
      data.terraform_remote_state.bastion.outputs.ssh_sg_id,
      data.terraform_remote_state.main.outputs.sg_access_to_internet
    ]
    #availability_zone = join(", ", data.terraform_remote_state.main.outputs.availability_zones.*)
    subnet_id         = join(", ", data.terraform_remote_state.main.outputs.private_subnet_id.*)
    tags              = merge(var.tags, map("Name", join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri"])))
  }

  lifecycle {
    ignore_changes = [
      valid_until,
      #launch_specification
    ]
  }
}
