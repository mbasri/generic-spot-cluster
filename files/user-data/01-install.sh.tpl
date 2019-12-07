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
