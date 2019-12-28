resource "aws_lambda_function" "tagger" {
  filename                       = "${path.module}/files/lambda/tagger.zip"
  description                    = "[Terraform] Lambda used to set the host index for the ECS SPOT cluster"
  function_name                  = join("-", [local.prefix_name, "all", "tag", "lam"])
  role                           = aws_iam_role.tagger_execution_role.arn
  handler                        = "tagger.handler"
  source_code_hash               = data.archive_file.tagger.output_base64sha256
  runtime                        = "python3.7"
  reserved_concurrent_executions = 1
  timeout                        = 15
  kms_key_arn                    = data.aws_kms_alias.lambda.target_key_arn
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      cluster_name = aws_autoscaling_group.main.name
    }
  }

  tags = merge(var.tags, map("Name", join("-", [local.prefix_name, "all", "tag", "lam"])))
}

resource "aws_lambda_function" "lifecycle_hook" {
  filename                       = "${path.module}/files/lambda/lifecycle-hook.zip"
  description                    = "[Terraform] Lambda used to drain EC2 after a scale down"
  function_name                  = join("-", [local.prefix_name, "all", "hok", "lam"])
  role                           = aws_iam_role.lifecycle_hook_lambda.arn
  handler                        = "lifecycle-hook.handler"
  source_code_hash               = data.archive_file.lifecycle_hook.output_base64sha256
  runtime                        = "python3.7"
  reserved_concurrent_executions = 1
  timeout                        = 180
  kms_key_arn                    = data.aws_kms_alias.lambda.target_key_arn
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      cluster_name = aws_ecs_cluster.main.name
    }
  }

  tags    = merge(
    var.tags,
    map("Name", join("-", [local.prefix_name, "all", "hok", "lam"])),
    map("Technical:ECSClusterName",local.cluster_name)
  )
  
}
