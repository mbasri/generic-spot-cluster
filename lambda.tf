resource "aws_lambda_function" "tagger_lambda" {
  filename                       = "${path.module}/files/tagger.zip"
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
