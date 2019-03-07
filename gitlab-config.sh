#!/bin/bash
fqdn=$1


sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl openssh-server ca-certificates
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo EXTERNAL_URL="http://${fqdn}" apt-get install -y gitlab-ee