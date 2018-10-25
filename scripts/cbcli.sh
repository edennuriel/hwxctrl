#!/usr/bin/env bash
hwxctrl=~/hwxctrl
source $hwxctrl/scripts/utils.sh
source $hwxctrl/scripts/cb.sh

cbadd_blueprint() {

  [[ -z $1 ]] && echo must provide a blueprint file/url + optional name &&  return
  bp_file=$(readlink -m $1)
  [[ -f $bp_file ]] && bp="from-file --file $bp_file "
  [[ $(wget "$1" -o /tmp/url > /dev/null 2>&1) == 0 ]] && bp="from-url --url $1 "
  [[ -z $bp ]] && "must provide a bp file or uril" && return
  bp_name=$(basename $bp_file)
  bp_name=${bp_name/.*}
  [[ ! -z "$2" ]] && bp_name="$2"
  [[ $(cb blueprint list | jq -r '.[]|.Name' | grep -x $bp_name >/dev/null 2>&1 ) ]] && echo removing exiting blueprint "$bp_name" && cb blueprint delete --name "$bp_name"
  cb blueprint create $bp --name "$bp_name" 
}

cbadd_ldap_auth() {
 ##lots to do here - get this all populated by autohdp...

  cb ldap create --name ${1:-enldap} \
  --ldap-server ${2:-"ldap://$myip:389"} \
  --ldap-domain ${3:-TEST.LAB} \
  --ldap-bind-dn "${4:-cn=Manager,dc=hadoop,dc=io}" \
  --ldap-directory-type LDAP \
  --ldap-user-search-base ou=users,dc=hadoop,dc=io \
  --ldap-user-name-attribute uid \
  --ldap-user-object-class posixAccount \
  --ldap-group-member-attribute memberUid \
  --ldap-group-name-attribute cn \
  --ldap-group-object-class posixGroup \
  --ldap-group-search-base ou=groups,dc=hadoop,dc=io \
  --ldap-bind-password admin \
  --ldap-user-dn-pattern uid={0}

}

cbadd_dbs() {
echo
}

cbadd_cred() {
  [[ -z "$1" ]] && echo "Usage: ${FUNCNAME[0]} <credential file> [name]"
  cred=${1}
  name=${2}
  render_bash $cred > /tmp/cred
  echo cb credential create from-file --cli-input-json /tmp/cred ${name:+--name $name}
  cb credential create from-file --cli-input-json /tmp/cred --name $name 
  rm /tmp/cred
}

cbadd_mpacks(){
  [[ -z "$1" ]] && echo "usage: ${FUNCNAME[0]} <url> [name]" && return
  name=${2:-hdf32}
  cb mpack create --url "$1" --name "$name"

}

cbadd_proxy(){
echo
}

cbadd_recipe() {

  [[ -z "$1" ]] && echo "Usage: ${FUNCNAME[0]} <url/file> [pre|post] [name]" 
  recf=$(readlink -m $1)
  [[ -f $recf ]] && export rec=" from-file --file $recf " 
  [[ $(wget "$1" -o /tmp/url > /dev/null 2>&1) == 0 ]] && export rec=" from-url --url $1 "
  [[ -z $rec ]] && "must provide a bp file or uril" && return
  rtype="${2:-pre-ambari-start}"
  rec_name=$(basename "$rec")
  rec_name=${rec_name/.*}
  cb recipe delete --name ${3:-$rec_name}
  cb recipe create $rec --execution-type $rtype --name ${3:-$rec_name}
}

cb_get_args() {
  error="must provide a ${3:-url/file and opional name}"
  [[ -z $1 ]] && echo $error && return
  file=$(readlink -m "$1")
  [[ -f "$file" ]] && args=" from-file --file $file " 
  [[ -z $args ]] && [[ $(wget "$1" -o /tmp/url > /dev/null 2>&1) == 0 ]] && args=" from-url --url "$1" "
  [[ -z "$args" ]] && echo $error && return
  name=$(basename $file)
  name=${bp_name/.*}
  [[ ! -z "$2" ]] && name="$2"
  return "$args --name $name "
}