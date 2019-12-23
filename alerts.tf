resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = join("-", [local.prefix_name, "cpu", "hgt"])
  alarm_description   = "[Terraform] This metric monitors ecs cpu reservation"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  
  tags    = merge(
      var.tags,
      map("Name", join("-", [local.prefix_name, "cpu", "hgt"])),
      map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
        )

  lifecycle {
    create_before_destroy = true
  }
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
  threshold           = "90"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
  }
  
  tags    = merge(
      var.tags,
      map("Name", join("-", [local.prefix_name, "mem", "hgt"])),
      map("Technical:ECSClusterName",aws_ecs_cluster.main.name)
    )
    

  lifecycle {
    create_before_destroy = true
  }


}