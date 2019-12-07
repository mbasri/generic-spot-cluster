Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
Content-Type: text/cloud-boothook; charset="us-ascii"

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash
# Update, Upgrade the host
cloud-init-per once yum_update yum update -y
cloud-init-per once yum_upgrade yum upgrade -y
cloud-init-per once yum_install yum install -y awslogs jq docker python2-pip python3-pip git telnet

# Install Ansible
cloud-init-per once ansible_install pip3 install -U ansible
cloud-init-per once ansible_link /bin/ln -fs /usr/local/bin/ansible /usr/bin/ansible
cloud-init-per once ansible_playbook_link /bin/ln -fs /usr/local/bin/ansible-playbook /usr/bin/ansible-playbook
cloud-init-per once ansible_pull_link /bin/ln -fs /usr/local/bin/ansible-pull /usr/bin/ansible-pull

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash
set -e
set -x

echo ECS_CLUSTER=${ecs_cluster_name} >> /etc/ecs/ecs.config
echo ECS_AVAILABLE_LOGGING_DRIVERS='["splunk","awslogs","fluentd","gelf","syslog"]' >> /etc/ecs/ecs.config
echo ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=30m >> /etc/ecs/ecs.config
echo ECS_IMAGE_CLEANUP_INTERVAL=30m >> /etc/ecs/ecs.config
echo ECS_IMAGE_MINIMUM_CLEANUP_AGE=180m >> /etc/ecs/ecs.config
echo ECS_NUM_IMAGES_DELETE_PER_CYCLE=10 >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config

--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/usr/bin/env bash
# Configure the AWS default region
aws configure set default.region ${region}

# Init METADATA
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
INSTANCE_ID=`curl --retry 5 -q http://169.254.169.254/latest/meta-data/instance-id`
VOLUMES_ID=`aws ec2 describe-volumes \
  --filter "Name=attachment.instance-id, Values=$${INSTANCE_ID}" \
  --query "Volumes[].VolumeId" --out text`
NETWORKS_ID=`aws ec2 describe-network-interfaces \
  --filter "Name=attachment.instance-id, Values=$${INSTANCE_ID}" \
  --query "NetworkInterfaces[].NetworkInterfaceId" --out text`

# Update the hostname
retries=7
i=0
until aws lambda invoke --function-name ${tagger_lambda_name} --payload "{\"instance_id\":\"$${INSTANCE_ID}\"}" /tmp/counter; do
  exit=$?
  wait=$((2 ** $i))
  i=$(($i + 1))
  if [ $i -lt $retries ]; then
    echo "Retry $i/$retries exited $exit, retrying in $wait seconds..."
    sleep $wait
  else
    echo "Retry $i/$retries exited $exit, no more retries left."
    break
  fi
done

COUNT=`cat /tmp/counter | jq '.count'`
hostnamectl set-hostname ${hostname}-$${COUNT}

# Update the tags on EC2, EBS & ENI

#aws ec2 create-tags --resources $${INSTANCE_ID} --tags "Key=Count,Value=$${COUNT}"
aws ec2 create-tags --resources $${INSTANCE_ID} --tags "Key=Name,Value=${hostname}-$${COUNT}"
aws ec2 create-tags --resources $${VOLUMES_ID} --tags Key=Name,Value="${hostname}-ebs-$${COUNT}"
aws ec2 create-tags --resources $${NETWORKS_ID} --tags Key=Name,Value="${hostname}-eni-$${COUNT}"

aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Billing:Organisation,Value="${billing_organisation}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Billing:OrganisationUnit,Value="${billing_organisation_unit}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Billing:Application,Value="${billing_application}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Billing:Environment,Value="${billing_environment}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Billing:Contact,Value="${billing_contact}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Technical:Terraform,Value="${technical_terraform}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Technical:Version,Value="${technical_version}"
#aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Technical:Comment,Value="{technical_comment}"
#aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Security:Compliance,Value="{security_compliance}"
#aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Security:DataSensitity,Value="{security_data_sensitivity}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Security:Encryption,Value="${security_encryption}"
aws ec2 create-tags --resources $${VOLUMES_ID} $${NETWORKS_ID} --tags Key=Count,Value="$${COUNT}"

# Run ansible
#ansible-pull \
#  -U https://github.com/sensorgraph/ansible.git \
#  -e 'ansible_python_interpreter=/usr/bin/python2' \
#  bastion.yml
--==BOUNDARY==