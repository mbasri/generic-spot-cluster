resource "aws_ecs_cluster" "main" {
  name = local.cluster_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = merge(var.tags, map("Name", join("-", [local.prefix_name, "pri"])))
}

resource "aws_cloudwatch_log_group" "main" {
  name = "/aws/ecs/${local.cluster_name}"
  tags = merge(
    var.tags,
    map("Name", join("-", [local.prefix_name, "pri", "log"])),
    map("Technical:ECSClusterName", local.cluster_name)
  )
}

resource "aws_lb" "main" {
  name               = join("-", [local.prefix_name, "pri"])
  load_balancer_type = "application"
  internal           = false
  subnets            = data.terraform_remote_state.main.outputs.public_subnet_id.*
  security_groups = [
    data.terraform_remote_state.main.outputs.sg_public_web_lb,
    data.terraform_remote_state.main.outputs.sg_access_to_private_web_app
  ]
  idle_timeout = 20

  access_logs {
    bucket  = data.terraform_remote_state.main.outputs.bucket_name_lb_accesslog_bucket
    prefix  = join("-", [local.prefix_name, "pri"])
    enabled = true
  }

  tags = merge(
    var.tags,
    map("Name", join("-", [local.prefix_name, "pri"])),
    map("Technical:ECSClusterName", local.cluster_name)
  )

}

resource "aws_lb_listener" "main_80" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      //message_body =
      status_code = "200"
    }
    //target_group_arn = aws_lb_target_group.main.arn
  }
}

/*
resource "aws_lb_listener" "main_443" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type           = "fixed-response"
    fixed_response  {
      content_type = "text/plain"
      //message_body =
      status_code  =  "200"
    }
    //target_group_arn = aws_lb_target_group.main.arn
  }
}
*/

resource "tls_private_key" "main" {
  algorithm = "RSA"
}

resource "aws_key_pair" "main" {
  key_name   = join("-", [local.prefix_name, "pri"])
  public_key = tls_private_key.main.public_key_openssh
}

resource "aws_secretsmanager_secret" "main" {
  name                    = join("-", [local.prefix_name, "pri"])
  recovery_window_in_days = 0
  description             = "[Terraform] SSH root key for '${aws_ecs_cluster.main.name}'' cluster"
  tags                    = merge(var.tags, map("Name", join("-", [local.prefix_name, "pri"])))
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_string = jsonencode(merge(map("keypair", tls_private_key.main.private_key_pem)))
}

resource "aws_launch_template" "main" {
  name        = join("-", [local.prefix_name, "pri", "spt"])
  description = "[Terraform] Launch template for '${var.tags["Billing:Application"]}' Application"
  iam_instance_profile {
    name = aws_iam_instance_profile.main.name
  }
  image_id = data.aws_ami.main.image_id
  key_name = aws_key_pair.main.key_name
  vpc_security_group_ids = [
    data.terraform_remote_state.bastion.outputs.ssh_sg_id,
    data.terraform_remote_state.main.outputs.sg_access_to_internet
  ]
  instance_type = "t2.small"
  user_data     = data.template_cloudinit_config.main.rendered

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      encrypted   = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name                = join("-", [local.prefix_name, "pri", "asg"])
  availability_zones  = data.terraform_remote_state.main.outputs.availability_zones
  min_size            = "1" // length(data.terraform_remote_state.main.outputs.availability_zones)
  desired_capacity    = length(data.terraform_remote_state.main.outputs.availability_zones)
  max_size            = "5" // length(data.terraform_remote_state.main.outputs.availability_zones)
  vpc_zone_identifier = data.terraform_remote_state.main.outputs.private_subnet_id.*
  //target_group_arns           = [ aws_lb_target_group.main.arn ]
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  metrics_granularity       = "1Minute"
  health_check_grace_period = "120"
  default_cooldown          = "300"

  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"

    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.main.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = ["t2.small", "t2.medium"]
        content {
          instance_type = override.value
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = join("-", [local.prefix_name, "pri", "ec2", "0"])
    propagate_at_launch = true
  }

  tag {
    key                 = "Technical:ECSClusterName"
    value               = local.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_resourcegroups_group" "test" {
  name = join("-", [local.prefix_name, "pri"])

  resource_query {
    query = data.template_file.resource_groups.rendered
  }
}


resource "aws_autoscaling_schedule" "week_scale_up" {
  scheduled_action_name  = join("-", [local.prefix_name, "pri", "sch", "wku"])
  min_size               = length(data.terraform_remote_state.main.outputs.availability_zones)
  max_size               = length(data.terraform_remote_state.main.outputs.availability_zones)
  desired_capacity       = length(data.terraform_remote_state.main.outputs.availability_zones)
  recurrence             = var.schedule_scale_up_and_down["week_scale_up"]
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_schedule" "week_scale_down" {
  scheduled_action_name  = join("-", [local.prefix_name, "pri", "sch", "wkd"])
  min_size               = "0"
  max_size               = "0"
  desired_capacity       = "0"
  recurrence             = var.schedule_scale_up_and_down["week_scale_down"]
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_schedule" "weekend_scale_up" {
  scheduled_action_name  = join("-", [local.prefix_name, "pri", "sch", "weu"])
  min_size               = length(data.terraform_remote_state.main.outputs.availability_zones)
  max_size               = length(data.terraform_remote_state.main.outputs.availability_zones)
  desired_capacity       = length(data.terraform_remote_state.main.outputs.availability_zones)
  recurrence             = var.schedule_scale_up_and_down["weekend_scale_up"]
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_schedule" "weekend_scale_down" {
  scheduled_action_name  = join("-", [local.prefix_name, "pri", "sch", "wed"])
  min_size               = "0"
  max_size               = "0"
  desired_capacity       = "0"
  recurrence             = var.schedule_scale_up_and_down["weekend_scale_down"]
  autoscaling_group_name = aws_autoscaling_group.main.name
}
