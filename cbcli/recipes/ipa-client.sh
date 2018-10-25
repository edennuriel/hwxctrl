#!/usr/bin/env bash
export dom=$(hostname -d)
export host=$(hostname -f)
export ipa="${1:-enctrl.field.hortonworks.com}"

REALM=${2:-$dom}
PASSWORD=${3:-admin1234}
NAME=${4:-enctrl.hortonworks.net}
export IP=$(host $ipa | cut -d" " -f4)
DOMAIN=${5:-$dom}
export REALM=${REALM^^}
echo ipa $ipa NAME $NAME DOMAIN $DOMAIN REALM $REALM PASS $PASSWORD

install_ipa_client() {
  sudo yum install -y ipa-client > /dev/null 2>&1
  sudo yum update -y curl libcurl nss > /dev/null 2>&1
}

update_resolver() {
  sudo mv /etc/resolv.conf /etc/resolv.conf.bak
  cat > /tmp/resolv.conf << EOF
search $DOMAIN
nameserver $IP
EOF
  sudo mv /tmp/resolv.conf /etc
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

main() {
  install_ipa_client 
  setup_ipa_client
}

main
