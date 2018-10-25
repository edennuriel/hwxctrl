#!/bin/bash	

global-prms() {
  PASSWORD=admin1234
  HOSTNAME=$(hostname)
  DOMAIN=$(hostname -d)
}  

ipa_prm(){
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

uodate_resolver_unbound() {
  hostnamectl set-hostname `hostname -f`
  cat >/etc/unbound/conf.d/02-ipa.conf<<EOF
forward-zone:
  name: "hortonworks.net"
  forward-addr: $IPA_IP 
EOF

  pkill -SIGHUP unbound
}

update_resolver_ipa() {
  sudo mv /etc/resolv.conf /etc/resolv.conf.bak
  cat > /tmp/resolv.conf << EOF
search $DOMAIN
nameserver $IP
EOF
  sudo mv /tmp/resolv.conf /etc
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

remount_tmpfs() {
  mount -o remount,exec /tmp
}

setup_truststore_ipa() {
  getenforce
  sudo setenforce 0
  echo $PASSWORD | kinit admin
  sudo mkdir -p /etc/security/certificates/
  sudo cd /etc/security/certificates/
  sudo ipa-getcert request -v -f /etc/security/certificates/host.crt -k /etc/security/certificates/host.key
  #sudo /usr/java/default/bin/keytool -list  -keystore /etc/pki/java/cacerts  -v -storepass $PASSWORD | grep ipa
}

secure_ambari_passwords() {
  sudo ambari-server setup-security --security-option=setup-truststore \
  --truststore-type=jks \
  --truststore-path=/etc/pki/java/cacerts \
  --truststore-password=$PASSWORD
  
  sudo ambari-server restart
}

secure_ambari_com() {
  sudo ambari-server setup-security --security-option setup-https \
  --import-cert-path=/etc/security/certificates/host.crt \
  --import-key-path=/etc/security/certificates/host.key \
  --api-ssl-port=8444 \
  --pem-password=$PASSWORD \
  --api-ssl=true
}

