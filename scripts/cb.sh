#!/usr/bin/env bash -x
### Cloudbreak# ##

cb_prms(){
  export cbver="2.7.1"
  export myip=$(hostname --ip-address)
  export user=enuriel
  export password=admin1234
  export CB_PORT=8888
  export HTTP_PORT=1800
  export HTTPS_PORT=1400
}

configure_cbd_ldap() {
  #install client
  yum install -y ldap-utils
  cd ~/cloudbreak
  cbd kill
  sudo tee -a uaa-changes.yml << EOF
spring_profiles: postgresql,ldap

ldap:
  profile:
    file: ldap/ldap-search-and-bind.xml
  base:
    url: ldap://${myip}:389
    userDn: cn=admin,dc=hwx,dc=lab
    password: ${password:-admin}
    searchBase: ou=users,dc=hwx,dc=lab
    searchFilter: mail={0}
  groups:
    file: ldap/ldap-groups-map-to-scopes.xml
    searchBase: ou=groups,dc=hwx,dc=lab
    searchSubtree: false
    maxSearchDepth: 1
    groupSearchFilter: member={0}
    autoAdd: true
EOF
  cbd regenerate
  cbd start
  cbd util execute-ldap-mapping  cn=cbd,cn=groups,cn=compat,dc=hwx,dc=lab
}


install_cbcli() {
  cb_prms
  curl -Ls https://s3-us-west-2.amazonaws.com/cb-cli/cb-cli_${cbver}_Linux_x86_64.tgz | sudo tar -xz -C /usr/local/bin cb
  cb configure --server $(hostname --ip-address):$HTTPS_PORT --username ${user} --password ${password:-admin}
}

install_cbd_bin(){
  cb_prms
  mkdir -p ~/bin
  export cbver=${1:-2.7.1} #latest ga is default
  cbdir=~/cloudbreak/$cbver
  mkdir -p $cbdir && cd $cbdir 
  curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_"$cbver"_$(uname)_x86_64.tgz |  tar -xz -C /tmp cbd
  mv /tmp/cbd ~/bin/cbd${cbver}
  ln -s ~/bin/cbd${cbver} $cbdir/cbd
  $cbdir/cbd --version
}

install_cbd_dev(){
  cb_prms
  mkdir ~/cloudbreak
  cd ~/cloudbreak
  # check if go is installed and if not..
  # install_go

  go get -u github.com/jteeuwen/go-bindata
  go get -u github.com/hortonworks/cloudbreak-deployer
  ln -s $GOPATH//src/github.com/hortonworks/cloudbreak-deployer
  cd cloudbreak-deployer

  git checkout v${cbver}
  make deps
  make build
  mkdir ~/bin > /dev/null 2>&1
  cp build/Linux/cbd ~/bin/cbd${cbver}
  alias cbd="/home/centos/bin/cbd${cbver}"
  sudo ln -s ~/bin/cbd${cbver} /usr/bin/cbd
}

create_cbd_profile() {
  dockerip="$(ip -4 addr show docker0 | grep -Po 'inet \K(\d+\.\d+\.\d+\.\d+)')"
  cb_prms
  cd "$1"
  echo "export UAA_DEFAULT_USER=${username:-enuriel}" > Profile
  echo "export UAA_DEFAULT_USER_EMAIL=${username:-enuriel}" > Profile
  echo "export UAA_DEFAULT_USER_PW=${password:-admini1234}" >> Profile
  echo "export PUBLIC_IP=${myip}" >> Profile
  echo "export PRIVATE_IP=${dockerip}" >> Profile
  echo "export CB_PORT=$CB_PORT" >> Profile
  echo "export PUBLIC_HTTP_PORT=$HTTP_PORT" >> Profile
  echo "export PUBLIC_HTTPS_PORT=$HTTPS_PORT" >> Profile
  echo "export CERT_VALIDATION=false " >> Profile
}
launch_cloudbreak() {
  cb_prms
  cbver=${1:-2.7.1}
  cbdir=~/cloudbreak/$cbver
  create_cbd_profile $cbdir
  ./cbd generate  && ./cbd start

}

cbipa() {
  echo
}

cbldap() {
echo 
}

