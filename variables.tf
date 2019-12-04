variable "tags" {
  type        = map
  description = "Default tags to be applied on 'Xiaomi Mi Home Security Camera 360 Backup' infrastructure"
  default     = {
    "Billing:Organisation"     = "Kibadex"
    "Billing:OrganisationUnit" = "Kibadex Labs"
    "Billing:Application"      = "Generic Spot cluster"
    "Billing:Environment"      = "Prod"
    "Billing:Contact"          = "mohamed.basri@outlook.com"
    "Technical:Terraform"      = "True"
    "Technical:Version"        = "1.0.0"
    #"Technical:Comment"        = "Managed by Terraform"
    #"Security:Compliance"      = "HIPAA"
    #"Security:DataSensitity"   = "1"
    "Security:Encryption"      = "True"
  }
}

variable "name" {
  type        = map
  description = "Default tags name to be applied on the infrastructure for the resources names"
  default     = {
    Application      = "gsc"
    Environment      = "prd"
    Organisation     = "kbd"
    OrganisationUnit = "lab"
  }
}
