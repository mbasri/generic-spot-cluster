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

# User data

data "template_file" "install" {
  template = file("${path.module}/files/user-data/01-install.sh.tpl")
}

data "template_file" "init_ecs" {
  template = file("${path.module}/files/user-data/02-init-ecs.sh.tpl")
  vars = {
    ecs_cluster_name = aws_ecs_cluster.main.name
  }
}

data "template_file" "tagger" {
  template = file("${path.module}/files/user-data/03-tagger.sh.tpl")
  vars = {
    region                    = data.terraform_remote_state.main.outputs.region
    hostname                  = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "pri", "spt"])
    tagger_lambda_name        = join("-",[var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"], "all", "tag", "lam"])

    billing_organisation      = var.tags["Billing:Organisation"]
    billing_organisation_unit = var.tags["Billing:OrganisationUnit"]
    billing_application       = var.tags["Billing:Application"]
    billing_environment       = var.tags["Billing:Environment"]
    billing_contact           = var.tags["Billing:Contact"]
    technical_terraform       = var.tags["Technical:Terraform"]
    technical_version         = var.tags["Technical:Version"]
    #technical_comment         = var.tags["Technical:Comment"]
    #security_compliance       = var.tags["Security:Compliance"]
    #security_data_sensitivity = var.tags["Security:DataSensitity"]
    security_encryption       = var.tags["Security:Encryption"]
  }
}

data "template_cloudinit_config" "main" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.install.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.init_ecs.rendered
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.tagger.rendered
  }
}

# Lambda for tagging EBS & ENI
data "archive_file" "tagger" {
  type        = "zip"
  source_file = "${path.module}/files/tagger.py"
  output_path = "${path.module}/files/tagger.zip"
}

# IAM Policies
data "aws_iam_policy" "cloud_watch_agent" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"  
}

data "aws_iam_policy" "ssm" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"  
}

data "aws_iam_policy" "ssm_automation" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMAutomationRole"
}

data "aws_iam_policy" "ecs" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

data "aws_iam_policy" "xray" {
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

data "aws_iam_role" "spot_fleet" {
  name = "aws-ec2-spot-fleet-tagging-role"
}

data "template_file" "tags_policy" {
  template = file("files/iam/tags-policy.json.tpl")
}

data "template_file" "cwl_policy" {
  template = file("files/iam/cwl-policy.json.tpl")
}

data "template_file" "ec2_policy" {
  template = file("files/iam/ec2-policy.json.tpl")
}

data "template_file" "lambda_policy" {
  template = file("files/iam/lambda-policy.json.tpl")
  vars     = {
            tagger_lambda_arn = aws_lambda_function.tagger_lambda.arn
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