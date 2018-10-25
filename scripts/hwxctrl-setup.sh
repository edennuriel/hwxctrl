#!/usr/bin/env bash 
### Base and Infra ###
source utils.sh
sourceall

#install all dependency packages
prep() {
  dolog yum upgrade -y 
  dolog yum -y groupinstall "Development Tools" 
  dolog yum -y install jq git readline-devel zlib-devel bzip2-devel sqlite-devel openssl-devel bind-utils jq wget 
}



install_docker() {
  dolog install -y yum-utils device-mapper-persistent-data lvm2 
  dolog  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 
  dolog yum -y install docker-ce 
  start_and_enable docker
  dolog pip install docker-compose 
  dolog groupadd docker
  dolog usermod -aG docker centos
  dolog usermod -aG docker cloudbreak
  echo In order to run docker as centos you need to restart the vm
  dolog echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
  sudo sysctl -w net.ipv4.ip_forward=1
}

install_hwxctrl_simple() {
	echo sourceall
	sourceall
	echo prep
	prep
	# install python ruby docker hub git-crypt tmux vi
	echo install_python 
	install_python 
	#echo install_go
	install_go
	echo install_ruby_dev - need version gt 2.2 for hub so need to build...
	install_ruby_dev
	echo install_java_maven
	install_java_maven
	echo install_docker
	install_docker
	echo install_hub
	install_hub
	#install_tmux
	echo install_git_crypt
	install_git_crypt
	echo configure_git
	configure_git
	echo install and setup ipa

        source ~/hwxctrl/scripts/ipa.sh
        sethostname
        install_ipa
        setup ipa
	configure_resolve_conf
	systemctl restart named-pkcs11

        # not listenining on docker interface 
        # get reference and configure cb (credentials, dbs, bps, etc...)
	# clone repos
	echo install_cbd_bin
	install_cbd_bin
	echo launch_cloudbreak
	launch_cloudbreak
	echo install_cbcli
	install_cbcli
}
