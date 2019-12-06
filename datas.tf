# Reference : https://github.com/sensorgraph/infra
data "terraform_remote_state" "main" {
  backend = "s3"
  config = {
    bucket = "tfstate.kibadex.net"
    key    = "infra/terraform.tfstate"
    region = "eu-west-3"
  }
}

data "terraform_remote_state" "bastion" {
  backend = "s3"
  config = {
    bucket = "tfstate.kibadex.net"
    key    = "bastion/terraform.tfstate"
    region = "eu-west-3"
  }
}

data "aws_caller_identity" "current" {}

data "aws_ami" "main" {
  most_recent  = true
  owners = ["amazon"]

    filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# KMS keys
data "aws_kms_alias" "lambda" {
  name = "alias/aws/lambda"
}

data "aws_kms_alias" "s3" {
  name = "alias/aws/s3"
}

data "aws_kms_alias" "sqs" {
  name = "alias/aws/sqs"
}

data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}

data "aws_iam_policy" "xray" {
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

data "aws_iam_role" "spot_fleet" {
  name = "aws-ec2-spot-fleet-tagging-role"
}
