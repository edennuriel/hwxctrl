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
  # add a resolve line for field.hortonworks.com for Openstack setup as this will be lost....
  echo 172.26.148.10 field.hortonworks.com >> /etc/hosts

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
   export LDGRPOC="${3:ipausergroup}"
   export LDUSROC="${4:posixaccount}"

   ambari-server setup-ldap --ldap-force-setup \
   --ldap-ur='enctrl.field.hortonworks.com:636' \
   --ldap-secondary-url='enctrl.field.hortonworks.com:636' \
   --ldap-ssl='true' \
   --ldap-type='IPA' \
   --ldap-user-class="'"${LDUSROC}"'" \
   --ldap-user-attr='uid' \
   --ldap-group-class="'"${LDGRPOC}"'" \
   --ldap-group-attr='cn' \
   --ldap-member-attr='member' \
   --ldap-dn='dn' \
   --ldap-base-dn='cn=accounts,dc=field,dc=hortonworks,dc=com' \
   --ldap-manager-dn='uid=ldapbind,cn=users,cn=accounts,dc=field,dc=hortonworks,dc=com' \
   --ldap-manager-password="$PASSWORD" \
   --ldap-referral="follow" \
   --ldap-bind-anonym="fasle" \
   --ldap-sync-username-collisions-behavior="skip" \
   --ldap-sync-disable-endpoint-identification="true" \
   --ldap-force-lowercase-usernames="false" \
   --ldap-pagination-enabled="true" \
   --ambari-admin-username="$ADMIN" \
   --ambari-admin-password="$PASSWORD" \
   --truststore-type="jks" \
   --truststore-path="/etc/pki/java/cacerts" \
   --truststore-password="$PASSWORD" \
   --ldap-save-settings \
   --ldap-force-setup \
   --truststore-reconfigure
 }

ambari_ldap_setup_expect() {
  [[ -z $(rpm -qa | grep expect) ]] && yum install -y expect > /dev/null 2>&1
  export PASSWORD=${1:-admin1234}
  export ADMIN=${2:-admin}
  export LDGRPOC="${3:ipausergroup}"
  export LDUSROC="${4:posixaccount}"
  read -r -d '' exp_cmds <<'EOD'

  set send_slow {10 0.01}
  spawn ambari-server setup-ldap --ldap-force-setup

  expect "Please select the type of LDAP you want to use "
  send -s "IPA\r"
  expect "Primary LDAP Host "
  send -s "enctrl.field.hortonworks.com\r"
  expect "Primary LDAP Port "
  send -s "636\r"
  expect "Secondary LDAP Host <Optional>"
  send -s "\r"
  expect "Secondary LDAP Port <Optional>"
  send -s "\r"
  expect "Use SSL "
  send -s "true\r"
  expect "Do you want to provide custom TrustStore for Ambari "
  send -s "y\r"
  expect "TrustStore type "
  send -s "jks\r"
  expect "Path to TrustStore file "
  send -s "/etc/pki/java/cacerts\r"
  expect "Password for TrustStore"
  send -s "$env(PASSWORD)\r"
  expect "Re-enter password"
  send -s "$env(PASSWORD)\r"
  expect "User object class "
  send -s "$env(LDUSROC)\r"
  expect "User ID attribute "
  send -s "uid\r"
  expect "Group object class "
  send -s "$env(LDGRPOC)\r"
  expect "Group name attribute "
  send -s "cn\r"
  expect "Group member attribute "
  send -s "member\r"
  expect "Distinguished name attribute "
  send -s "dn\r"
  expect "Search Base "
  send -s "cn=accounts,dc=field,dc=hortonworks,dc=com\r"
  expect "Referral method "
  send -s "follow\r"
  expect "Bind anonymously "
  send -s "false\r"
  expect "Bind DN "
  send -s "uid=ldapbind,cn=users,cn=accounts,dc=field,dc=hortonworks,dc=com\r"
  expect "Enter Bind DN Password"
  send -s "$env(PASSWORD)\r"
  expect "Confirm Bind DN Password"
  send -s "$env(PASSWORD)\r"
  expect "Handling behavior for username collisions "
  send -s "skip\r"
  expect "Force lower-case user names "
  send -s "\r"
  expect "Results from LDAP are paginated when requested "
  send -s "\r"
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
  ambari-server sync-ldap --all --ldap-sync-admin-name=$ADMIN --ldap-sync-admin-password=$PASSWORD $@
}


install_ldap_tools() {
  yum install -y openldap-clients > /dev/null 2>&1
}

lds(){
  # Search for a valid uid and ensure the searchbase, bind dn, and ldapurl resolve properly
  ldapsearch -D ${LDAP_BINDDN} \
  -w ${LDAP_BINDDN_PW} \
  -b ${LDAP_SEARCHBASE} \
  -H ldaps://${LDAP_URL} $@
}

ipausers() {
  lds "(objectclass=posixaccount)" uid 
}

ipagroups() {
  lds "(objectclass=ipausergroup)" cn
}

create_db() {
  dbname=${1}
  dbtype="${2:-mysql}"
  dbuser="${3:-$dbname}"
  dbpass="${4:-$dbname}"
  [[ -z "$dbname" ]] && echo "Db name is required" && return 1
  case "$dbtype" in
  mysql )
    ## check my sql is installed
    sudo mysql -e "CREATE DATABASE $dbname;"
    #GRANT seems to add the user, so saved a line here...
    sudo mysql -e "GRANT ALL PRIVILEGES on $dbname.* to '$dbuser'@'%' identified by '$dbpass';"
    sudo mysql -e "GRANT ALL PRIVILEGES on $dbname.* to '$dbuser'@'localhost' identified by '$dbpass';"
  ;;
  * )
    echo "db type is mysql or postgres"
    return 1
  ;;
  esac
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
  for db in ranger rangerkms registry oozie druid superset streamline 
  do 
    create_db $db
  done 
}

amb_post() {
  global_prms
  ipa_prms
  ambari_truststore_ipa
  ambari_secure_passwords
  ambari_server_fqdn_hack
  retry ambari_enable_https 5 5
  ambari-server restart
  wait-for-ambari
  ambari_ldap_setup
  ambari_ldap_sync

}

##
#recipe files
global_prms
ipa_prms
#all_pre
#amb_pre
#amb_post
