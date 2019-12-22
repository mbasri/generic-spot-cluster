output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "Cluster name"
}

output "alb_name" {
  value       = aws_lb.main.name
  description = "Name of the load balencer"
}

output "alb_url" {
  value       = aws_lb.main.dns_name
  description = "URL of the load balencer"
}

output "subnets" {
  value       = aws_autoscaling_group.main.vpc_zone_identifier
  description = "Subnets of the cluster"
}

output "alb_accesslog" {
  value       = data.terraform_remote_state.main.outputs.bucket_name_lb_accesslog_bucket
  description = "Bucket name to load balencer acceslog"
}

output "cluster_ssh_private_key" {
    value       = tls_private_key.main.private_key_pem
    description = "SSH key to use for the cluster"
}

output "ec2_image_name" {
  value = data.aws_ami.main.name
}

output "test" {
  value = data.aws_ami.main.image_id
}