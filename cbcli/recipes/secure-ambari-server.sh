#set name of instance to ipa.someawsdomain
hostname=$(hostname)
domain=$(hostname -d)

export REALM=${1:-$domain}
export PASSWORD=${2:-admin1234}
export NAME=${4:-$hostname}
export DOMAIN=${3:-$domain}
REALM=${REALM^^}
export IP=$(hostname --ip-address)
echo "IP is ${IP}"
echo "REALM ${REALM} PASSWORD ${PASSWORD} NAME ${NAME} DOMAIN ${DOMAIN}"

setup_truststore() {
  getenforce
  sudo setenforce 0
  echo $PASSWORD | kinit admin
  sudo mkdir -p /etc/security/certificates/
  sudo cd /etc/security/certificates/
  sudo ipa-getcert request -v -f /etc/security/certificates/host.crt -k /etc/security/certificates/host.key

  sudo /usr/java/default/bin/keytool -list \
  -keystore /etc/pki/java/cacerts \
  -v -storepass $PASSWORD | grep ipa

  sudo ambari-server setup-security --security-option=setup-truststore --truststore-type=jks --truststore-path=/etc/pki/java/cacerts --truststo
re-password=$PASSWORD
  sudo ambari-server restart
}

setup_ambari_tls() {
  sudo ambari-server setup-security --security-option setup-https \
  --import-cert-path=/etc/security/certificates/host.crt \
  --import-key-path=/etc/security/certificates/host.key \
  --api-ssl-port=8444 \
  --pem-password=$PASSWORD \
  --api-ssl=true
}
