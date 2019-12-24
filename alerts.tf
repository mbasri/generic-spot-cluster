resource "aws_autoscaling_policy" "scale_up" {
  name                   = join("-", [local.prefix_name, "sup"])
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
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
  period              = "300"
  statistic           = "Maximum"
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
  period              = "300"
  statistic           = "Maximum"
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
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
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
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
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
