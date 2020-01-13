locals {
  prefix_name  = join("-", [var.name["Organisation"], var.name["OrganisationUnit"], var.name["Application"], var.name["Environment"]])
  cluster_name = join("-", [local.prefix_name, "pri"])
}
