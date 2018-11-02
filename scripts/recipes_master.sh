#!/bin/bash

retry() {
  [[ -z $1 ]] && echo missing command to try && return
  cmd=${1}
  tries=${2:-3}
  wait=${3:-1}
  for ((try=1; try <= tries; try++))
  do
    echo "tryng $cmd.... ( $try of $tries)"
    $cmd
    [[ $? == 0 ]] && return
    sleep $wait
  done
}

log() {
  echo -n ${FUNCNAME[0]} ${FUNCNAME[1]} :
  [[ ${#@} == 1 ]] && echo $1 && return
  printf '\n\t\t%s' "$@"
  echo

}

penv() {
  for arg in $@
  do
     echo $arg=${!arg}
  done
}

global_prms() {
  PASSWORD=admin1234
  HOSTNAME=$(hostname)
  DOMAIN=$(hostname -d)
  FQDN=$(hostname -f)
  IP=$(hostname --ip-address)
  log $(penv PASSWORD HOSTNAME DOMAIN FQDN IP)
}

ipa_prms(){
  #set name of instance to ipa.someawsdomain
  IPA_HOST="${1:-enctrl.field.hortonworks.com}"
  IPA_IP=$(host $IPA_HOST | cut -d" " -f4)
  REALM=${2:-$DOMAIN}
  REALM=${REALM^^}
  log $(penv IPA_HOST IPA_IP REALM)
}

ldap_prms() {
  global_prms
  ipa_prms
  LDAP_BASE=${1:-cn=accounts,dc=field,dc=hortonworks,dc=com}
  # ,cn=users,cn=accounts for IPA
  LDAP_USERS_BASE=${2:-"cn=users"},${LDAP_BASE}
  LDAP_GROUPS_BASE=${2:-"cn=groups"},${LDAP_BASE}
  LDAP_USER=${3:-"ldapbind"}
  LDAP_URL="$IPA_HOST:636"
  LDAP_BINDDN="uid=$LDAP_USER,$LDAP_USERS_BASE"
  LDAP_BINDDN_PW="admin1234"
  LDAP_SEARCHBASE="$LDAP_BASE"
  log $(penv LDAP_BASE LDAP_BINDDN LDAP_BINDDN_PW LDAP_URL)
}

install_ipa_client() {
  sudo yum install -y ipa-client > /dev/null 2>&1
  #sudo yum update -y curl libcurl nss > /dev/null 2>&1
}

setup_ipa_client() {
  export IPA_HOST="${1:-enctrl.field.hortonworks.com}"
  sudo ipa-client-install \
  --server=$IPA_HOST \
  --realm=$REALM \
  --domain=$DOMAIN \
  --mkhomedir \
  --principal=admin -w $PASSWORD \
  --ip-address=$IP \
  --force \
  --unattended
}

update_resolver_unbound() {
  hostnamectl set-hostname `hostname -f`
  cat >/etc/unbound/conf.d/02-ipa.conf<<EOF
forward-zone:
  name: "field.hortonworks.com"
  forward-addr: $IPA_IP
EOF

  pkill -SIGHUP unbound
}

install_mysql() {
  yum remove -y mysql57-community* > /dev/null 2>&1
  yum remove -y mysql56-server* > /dev/null 2>&1
  yum remove -y mysql-community* > /dev/null 2>&1
  rm -Rvf /var/lib/mysql > /dev/null 2>&1

  yum install -y epel-release > /dev/null 2>&1
  yum install -y libffi-devel.x86_64 > /dev/null 2>&1
  ln -s /usr/lib64/libffi.so.6 /usr/lib64/libffi.so.5

  yum install -y mysql-connector-java* > /dev/null 2>&1
}

remount_tmpfs() {
  mount -o remount,exec /tmp
}

ambari_mysql() {
  ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar

  if [[ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]]; then
	  yum install -y mysql56-server > /dev/null 2>&1
	  service mysqld start
	  chkconfig --add mysqld
	  chkconfig mysqld on
  else
	  yum localinstall -y https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm > /dev/null 2>&1
	  yum install -y mysql-community-server > /dev/null 2>&1
	  systemctl start mysqld.service
	  systemctl enable mysqld.service
  fi
}

ambari_truststore_ipa() {
  getenforce
  sudo setenforce 0
  echo $PASSWORD | kinit admin
  sudo mkdir -p /etc/security/certificates/ > /dev/null 2>&1
  sudo ipa-getcert request -v -f /etc/security/certificates/host.crt -k /etc/security/certificates/host.key
  sudo keytool -list -keystore /etc/pki/java/cacerts -v -storepass changeit -storepasswd -new $PASSWORD | grep ipa
}

ambari_secure_passwords() {
  sudo ambari-server setup-security --security-option=setup-truststore \
  --truststore-type=jks \
  --truststore-path=/etc/pki/java/cacerts \
  --truststore-password=$PASSWORD

  sudo ambari-server restart
}

ambari_server_fqdn_hack() {
  sed -i 's/\(^server.fqdn.service.url.*\)/#\1/;  /^#server.fqdn/ a server.fqdn.service.url=blah' /etc/ambari-server/conf/ambari.properties
}

ambari_enable_https(){
  if [[ -f /etc/security/certificates/host.crt ]] && [[ -f /etc/security/certificates/host.key ]]
  then
    sudo ambari-server setup-security --security-option setup-https \
    --import-cert-path=/etc/security/certificates/host.crt \
    --import-key-path=/etc/security/certificates/host.key \
    --api-ssl-port=8444 \
    --pem-password=$PASSWORD \
    --api-ssl=true
  else
     echo "missing required files "
     sudo ls -ltr /etc/security/certificates/
  fi
}

ambari_kerberos_ipa() {
  tmploc=/tmp/uc
  git clone https://github.com/crazyadmins/useful-scripts.git $tmploc
  cd useful-scripts/ambari/
  cat << EOF > ambari.props
CLUSTER_NAME=${cluster_name}
AMBARI_ADMIN_USER=admin
AMBARI_ADMIN_PASSWORD=${ambari_pass}
AMBARI_HOST=$(hostname -f)
KDC_HOST=${IPA_HOST}
REALM=${REALM}
KERBEROS_CLIENTS=$(hostname -f)
EOF
}
####

ambari_ldap_setup() {
  [[ -z $(rpm -qa | grep expect) ]] && yum install -y expect > /dev/null 2>&1
  export PASSWORD=${1:-admin1234}
  export ADMIN=${2:-admin}
  read -r -d '' exp_cmds <<'EOD'

  set send_slow {10 0.01}
  spawn ambari-server setup-ldap --ldap-force-setup

  ### Please select the type of LDAP you want to use (AD, IPA, Generic LDAP):IPA ###
  expect "Please select the type of LDAP you want to use "
  send -s "IPA\r"
  ### Primary LDAP Host (ipa.ambari.apache.org):enctrl.field.hortonworks.com ###
  expect "Primary LDAP Host "
  send -s "enctrl.field.hortonworks.com\r"
  ### Primary LDAP Port (636): ###
  expect "Primary LDAP Port "
  send -s "636\r"
  ### Secondary LDAP Host <Optional>: ###
  expect "Secondary LDAP Host <Optional>"
  send -s "\r"
  ### Secondary LDAP Port <Optional>: ###
  expect "Secondary LDAP Port <Optional>"
  send -s "\r"
  ### Use SSL [true/false] (true): ###
  expect "Use SSL "
  send -s "true\r"
  ### Do you want to provide custom TrustStore for Ambari [y/n] (y)? ###
  expect "Do you want to provide custom TrustStore for Ambari "
  send -s "y\r"
  ### TrustStore type [jks/jceks/pkcs12] (jks): ###
  expect "TrustStore type "
  send -s "jks\r"
  ### Path to TrustStore file (/etc/pki/java/cacerts): ###
  expect "Path to TrustStore file "
  send -s "/etc/pki/java/cacerts\r"
  ### Password for TrustStore:$env(PASSWORD) ###
  expect "Password for TrustStore"
  send -s "$env(PASSWORD)\r"
  ### Re-enter password:$env(PASSWORD) ###
  expect "Re-enter password"
  send -s "$env(PASSWORD)\r"
  ### User object class (posixUser): ###
  expect "User object class "
  send -s "posixUser\r"
  ### User ID attribute (uid): ###
  expect "User ID attribute "
  send -s "uid\r"
  ### Group object class (posixGroup): ###
  expect "Group object class "
  send -s "posixGroup\r"
  ### Group name attribute (cn): ###
  expect "Group name attribute "
  send -s "cn\r"
  ### Group member attribute (memberUid): member ###
  expect "Group member attribute "
  send -s "member\r"
  ### Distinguished name attribute (dn): ###
  expect "Distinguished name attribute "
  send -s "dn\r"
  ### Search Base (dc=ambari,dc=apache,dc=org):  cn=accounts,dc=field,dc=hortonworks,dc=com ###
  expect "Search Base "
  send -s "cn=accounts,dc=field,dc=hortonworks,dc=com\r"
  ### Referral method [follow/ignore] (follow): ###
  expect "Referral method "
  send -s "follow\r"
  ### Bind anonymously [true/false] (false): ###
  expect "Bind anonymously "
  send -s "false\r"
  ### Bind DN (uid=ldapbind,cn=users,cn=accounts,dc=ambari,dc=apache,dc=org): uid=ldapbind,cn=users,cn=accounts,dc=field,dc=hortonworks,dc=com ###
  expect "Bind DN "
  send -s "uid=ldapbind,cn=users,cn=accounts,dc=field,dc=hortonworks,dc=com\r"
  ### Enter Bind DN Password:$env(PASSWORD) ###
  expect "Enter Bind DN Password"
  send -s "$env(PASSWORD)\r"
  ### Confirm Bind DN Password:$env(PASSWORD) ###
  expect "Confirm Bind DN Password"
  send -s "$env(PASSWORD)\r"
  ### Handling behavior for username collisions [convert/skip] for LDAP sync (skip): ###
  expect "Handling behavior for username collisions "
  send -s "skip\r"
  ### Force lower-case user names [true/false]: ###
  expect "Force lower-case user names "
  send -s "\r"
  ### Results from LDAP are paginated when requested [true/false]: ###
  expect "Results from LDAP are paginated when requested "
  send -s "\r"
  ### Save settings:y ###
  expect "Save settings"
  send -s "y\r"

  expect "Enter Ambari Admin login:"
  send -s "$env(ADMIN)\r"
  expect  "Enter Ambari Admin password:"
  send -s "$env(PASSWORD)\r"

  expect eof
EOD
  read -r -d '' exp_cmd_no_comments <<< "$(echo "$exp_cmds" | grep -v '#')"
  exp_cmd_no_comments="${exp_cmd_no_comments//$'\n'/;};"
  expect -c  "$exp_cmd_no_comments"
}

ambari_ldap_sync() {
  ambari-server sync-ldap --all --ldap-sync-admin-name=$ADMIN --ldap-sync-admin-password=$PASSWORD
}



install_ldap_tools() {
  yum install -y openldap-clients > /dev/null 2>&1
}

lds(){
  # Search for a valid uid and ensure the searchbase, bind dn, and ldapurl resolve properly
  ldapsearch -D ${LDAP_BINDDN} \
  -w ${LDAP_BINDDN_PW} \
  -b ${LDAP_SEARCHBASE} \
  -H ldaps://${LDAP_URL} "${1}"
}

##recipe components
all_pre() {
  global_prms
  ipa_prms enctrl.field.hortonworks.com
  update_resolver_unbound
  install_mysql
  install_ipa_client
  remount_tmpfs
  setup_ipa_client
  install_ldap_tools
}

amb_pre() {
  all_pre
  ambari_mysql
}

amb_post() {
  global_prms
  ipa_prms
  ambari_truststore_ipa
  ambari_secure_passwords
  ambari_server_fqdn_hack
  retry ambari_enable_https 5 5
  #ambari-server restart
  #wait-for-ambari
  #ambari_ldap_setup
  #ambari_ldap_sync
}

##
#recipe files
global_prms
ipa_prms
#all_pre
#amb_pre
#amb_post
