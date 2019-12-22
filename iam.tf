#SPOT intances
resource "aws_iam_role" "main" {
  name               = join("-", [local.prefix_name, "pri", "iam", "rol"])
  description        = "[Terraform] IAM roles for EC2 Bastion"
  assume_role_policy = file("files/iam/ec2-role.json")
  tags               = merge (var.tags, map ("Name", join("-", [local.prefix_name, "pri", "rol"])))
}

resource "aws_iam_instance_profile" "main" {
  name = join("-", [local.prefix_name, "pri", "pro"])
  role = aws_iam_role.main.name
}

resource "aws_iam_role_policy_attachment" "archivelog" {
  role       = aws_iam_role.main.name
  policy_arn = data.terraform_remote_state.main.outputs.arn_archivelog_bucket
}

resource "aws_iam_role_policy" "lambda" {
  name   = join("-", [local.prefix_name, "pri", "pol", "lam"])
  role   = aws_iam_role.main.id
  policy = data.template_file.lambda_policy.rendered
}

resource "aws_iam_role_policy" "tags" {
  name   = join("-", [local.prefix_name, "pri", "pol", "tag"])
  role   = aws_iam_role.main.id
  policy = data.template_file.tags_policy.rendered
}

resource "aws_iam_role_policy" "cwl" {
  name   = join("-", [local.prefix_name, "pri", "pol", "cwl"])
  role   = aws_iam_role.main.id
  policy = data.template_file.cwl_policy.rendered
}

resource "aws_iam_role_policy_attachment" "cloud_watch_agent" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.cloud_watch_agent.arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.ssm.arn
}

resource "aws_iam_role_policy_attachment" "ssm_automation" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.ssm_automation.arn
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.ecs.arn
}

# Lambda tagger
resource "aws_iam_role" "tagger_execution_role" {
  name               = join("-", [local.prefix_name, "pri", "rol", "tag", "lam"])
  description        = "[Terraform] IAM roles for lambda used by the Bastion"
  assume_role_policy = file("files/iam/lambda-role.json")
  tags               = merge(var.tags, map("Name", join("-", [local.prefix_name, "pri", "rol", "tag", "lam"])))
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.tagger_execution_role.name
  policy_arn = data.aws_iam_policy.xray.arn
}

resource "aws_iam_role_policy" "ec2" {
  name   = join("-", [local.prefix_name, "pri", "pol", "ec2"])
  role   = aws_iam_role.tagger_execution_role.id
  policy = data.template_file.ec2_policy.rendered
}

resource "aws_iam_role_policy" "asg" {
  name   = join("-", [local.prefix_name, "pri", "pol", "asg"])
  role   = aws_iam_role.tagger_execution_role.id
  policy = data.template_file.asg_policy.rendered
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = join("-", [local.prefix_name, "pri", "pol", "log"])
  role   = aws_iam_role.tagger_execution_role.id
  policy = data.template_file.cwl_policy.rendered
}
