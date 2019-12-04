# Project to use for create '[generic-spot-instance](https://github.com/mbasri/generic-spot-cluster)' infrastructure

## How to create/destroy the infrastructure

### 1. Initialise you environmernt

```shell
aws configure
```

### 2. Create the infrastructure

```shell
terraform apply
```

### 3. Destroy the infrastructure

```shell
terraform destroy
```

## Dependencies of the infrastructure

* This project is based on the output of the [global infrastructure project](https://github.com/sensorgraph/infra) via the data block `terraform_remote_state`
* The project is built with the [v0.12.17](https://releases.hashicorp.com/terraform/) of Terraform

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| name | Default tags name to be applied on the infrastructure for the resources names| map | `...` | no |
| tags | Default tags to be applied on the infrastructure | map | `...` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_accesslog | Bucket name to load balencer acceslog |
| alb_url | Bucket name of the project |
| cluster_name | Cluster name |

## AWS architecture diagram

![files/lucidchart/x.png](files/lucidchart/x.png)

## Author

* [**Mohamed BASRI**](https://github.com/mbasri)

## License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details
