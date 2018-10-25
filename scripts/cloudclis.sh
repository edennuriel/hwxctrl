#!/usr/bin/env bash

### Cloud IaaS CLI ###

install_os_cli() {
  mkdir os
  cd os
  pyenv local os
  pip install -q python-openstackclient

  tee -a .os_plugins << EOF
barbican - Key Manager Service API
ceilometer - Telemetry API
cinder - Block Storage API and extensions
cloudkitty - Rating service API
designate - DNS service API
fuel - Deployment service API
glance - Image service API
gnocchi - Telemetry API v3
heat - Orchestration API
magnum - Container Infrastructure Management service API
manila - Shared file systems API
mistral - Workflow service API
monasca - Monitoring API
murano - Application catalog API
neutron - Networking API
nova - Compute API and extensions
sahara - Data Processing API
senlin - Clustering service API
swift - Object Storage API
trove - Database service API
EOF

  sudo mkdir /etc/openstack
  export osuser=enuriel
  read -p "Enter password for user ${osuser} :" -s OS_PASSWORD
  export OS_CLOUD=fld
  echo export OS_CLOUD=fld >> ~/.bash_profile
sudo tee -a /etc/openstack/clouds.yaml << EOF
clouds:
  fld:
    identity_api_version: 3
    auth:
      auth_url: http://172.26.148.10:5000/v3
      project_name: se
      username: $osuser
      password: $OS_PASSWORD
      domain_name: Default
    verify: False
    region_name: RegionOne
EOF
}

install_aws_cli() {
  pip install -qq awscli
  pip install -U awscli
  aws configure
}

install_azure_cli() {
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
  sudo yum install -y azure-cli
  # sudo yum update -y azure-cli
}

install_gcp_cli() {
  sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM

  sudo yum install -y google-cloud-sdk

  gcp_addon="google-cloud-sdk-app-engine-python "
  gcp_addon+="google-cloud-sdk-app-engine-python-extras"
  gcp_addon+="google-cloud-sdk-app-engine-java"
  gcp_addon+="google-cloud-sdk-app-engine-go"
  gcp_addon+="google-cloud-sdk-bigtable-emulator"
  gcp_addon+="google-cloud-sdk-datalab"
  gcp_addon+="google-cloud-sdk-datastore-emulator"
  gcp_addon+="google-cloud-sdk-cbt"
  gcp_addon+="google-cloud-sdk-pubsub-emulator"
  gcp_addon+="kubectl"

  for g in $gcp_addon; do $echo sudo yum install -y $g ;done
}




