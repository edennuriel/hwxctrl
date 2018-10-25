#!/bin/bash	

global_prms() {
  export PASSWORD=admin1234
  export HOSTNAME=$(hostname)
  export DOMAIN=$(hostname -d)
  export FQDB=$(hostmane -f)
}  

ipa_prms(){
  #set name of instance to ipa.someawsdomain
  export IPA_HOST="${1:-enctrl.hortonworks.net}"
  export IPA_IP=$(host $ipa | cut -d" " -f4)
  export REALM=${1:-$DOMAIN}
  export PASSWORD=${2:-admin1234}
  export NAME=${4:-$HOSTNAME}
  export DOMAIN=${3:-$DOMAIN}
  REALM=${REALM^^}
  export IP=$(hostname --ip-address)
  echo "IP is ${IP}"
  echo "REALM ${REALM} PASSWORD ${PASSWORD} NAME ${NAME} DOMAIN ${DOMAIN}"
}

install_ipa_client() {
  sudo yum install -y ipa-client > /dev/null 2>&1
  #sudo yum update -y curl libcurl nss > /dev/null 2>&1
}

setup_ipa_client() {
  sudo ipa-client-install \
  --server=$NAME \
  --realm=$REALM \
  --domain=$DOMAIN \
  --mkhomedir \
  --principal=admin -w $PASSWORD \
  --force \
  --unattended
}

update_resolver_unbound() {
  hostnamectl set-hostname `hostname -f`
  cat >/etc/unbound/conf.d/02-ipa.conf<<EOF
forward-zone:
  name: "hortonworks.net"
  forward-addr: $IPA_IP 
EOF

  pkill -SIGHUP unbound
}

install_mysql() {
  yum remove -y mysql57-community*
  yum remove -y mysql56-server*
  yum remove -y mysql-community*
  rm -Rvf /var/lib/mysql

  yum install -y epel-release
  yum install -y libffi-devel.x86_64
  ln -s /usr/lib64/libffi.so.6 /usr/lib64/libffi.so.5

  yum install -y mysql-connector-java*
}

remount_tmpfs() {
  mount -o remount,exec /tmp
}

ambari_mysql() {
  ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar

  if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then       	
	  yum install -y mysql56-server
	  service mysqld start
	  chkconfig --add mysqld
	  chkconfig mysqld on
  else
	  yum localinstall -y https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
	  yum install -y mysql-community-server
	  systemctl start mysqld.service
	  systemctl enable mysqld.service
  fi
}

ambari_truststore_ipa() {
  getenforce
  sudo setenforce 0
  echo $PASSWORD | kinit admin
  sudo mkdir -p /etc/security/certificates/
  sudo cd /etc/security/certificates/
  sudo ipa-getcert request -v -f /etc/security/certificates/host.crt -k /etc/security/certificates/host.key
  #sudo /usr/java/default/bin/keytool -list  -keystore /etc/pki/java/cacerts  -v -storepass $PASSWORD | grep ipa
}

ambari_secure_passwords() {
  sudo ambari-server setup-security --security-option=setup-truststore \
  --truststore-type=jks \
  --truststore-path=/etc/pki/java/cacerts \
  --truststore-password=$PASSWORD
  
  sudo ambari-server restart
}

ambari_enable_https(){
  sudo ambari-server setup-security --security-option setup-https \
  --import-cert-path=/etc/security/certificates/host.crt \
  --import-key-path=/etc/security/certificates/host.key \
  --api-ssl-port=8444 \
  --pem-password=$PASSWORD \
  --api-ssl=true
}

all_pre() {
  global_prms
  ipa_prms
  update_resolver_unbound
  install_mysql
  install_ipa_client
  remount_tmpfs
  setup_ipa_client
}

amb_pre() {
  global_prms
  ambari_mysql
}

amb_pos() {
  global_prms
  ipa_prms
  ambari_truststore_ipa
  ambari_secure_password
  ambari_enable_https
}

all_pre
