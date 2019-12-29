resource "aws_sns_topic" "main" {
  name              = join("-", [local.prefix_name, "sns"])
  display_name      = "[Terraform] Notification called from Lifecycle Hooks"
  kms_master_key_id = data.aws_kms_alias.sns.target_key_arn
  tags    = merge(
    var.tags,
    map("Name", join("-", [local.prefix_name, "sns"])),
    map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
      )
}

resource "aws_sns_topic_subscription" "main" {
  topic_arn = aws_sns_topic.main.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lifecycle_hook.arn
}

resource "aws_autoscaling_lifecycle_hook" "scale_down" {
  name                    = join("-", [local.prefix_name, "hok"])
  autoscaling_group_name  = aws_autoscaling_group.main.name
  default_result          = "ABANDON"
  heartbeat_timeout       = "900"
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = aws_sns_topic.main.arn
  role_arn                = aws_iam_role.lifecycle_hook.arn
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = join("-", [local.prefix_name, "sup"])
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = join("-", [local.prefix_name, "sdo"])
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.main.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = join("-", [local.prefix_name, "cpu", "hgt"])
  alarm_description   = "[Terraform] This metric monitors ecs cpu reservation"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "75"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
  
  tags    = merge(
      var.tags,
      map("Name", join("-", [local.prefix_name, "cpu", "hgt"])),
      map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
        )

}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = join("-", [local.prefix_name, "mem", "hgt"])
  alarm_description   = "[Terraform] This metric monitors ecs memory reservation"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "75"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
  
  tags    = merge(
      var.tags,
      map("Name", join("-", [local.prefix_name, "mem", "hgt"])),
      map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
    )

}


resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = join("-", [local.prefix_name, "cpu", "low"])
  alarm_description   = "[Terraform] Scale down if the cpu reservation is below 10% for 10 minutes"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "15"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "25"

  dimensions = {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }
  
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]

    tags    = merge(
      var.tags,
      map("Name", join("-", [local.prefix_name, "cpu", "low"])),
      map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
    )
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = join("-", [local.prefix_name, "mem", "low"])
  alarm_description   = "[Terraform] Scale down if the memory reservation is below 10% for 10 minutes"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "15"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "25"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }

  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]

  tags    = merge(
    var.tags,
    map("Name", join("-", [local.prefix_name, "mem", "low"])),
    map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
  )
}
