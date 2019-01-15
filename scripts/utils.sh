#!/usr/bin/env bash -x

join() {
  sed ':a;N;$!ba;s/\n/'"${1:-,}"'/g'  
}

sourceall() {
	for sh in $(awk '{print $1}' ~/hwxctrl/scripts/.ordered); do source ~/hwxctrl/scripts/$sh ; done
}

install() {
  yum install -y "$@" >/dev/null 2>&1
}


getdir() {
  pushd . > /dev/null 2>&1
  cd $(dirname $1) && pwd
  popd  > /dev/null 2>&1
}

log() {
  echo -n ${FUNCNAME[0]} ${FUNCNAME[1]} : 
  [[ ${#@} == 1 ]] && echo $1 && return
  printf '\n\t\t%s' "$@"
  echo
  
}

doo() {
    local s q f v r
    while getopts ":sqfv" opt; do
    case ${opt} in
      s ) # as root
        s="sudo";shift
        ;;
      q ) # silent
        r=' > /dev/null 2>&1' ; shift
       ;;
      f ) # log to file
        BS=$(basename $BASH_SOURCE)
        DLOG=${BS/.*}
        LOG=${GLOBAL_LOG:-$DLOG}
          r=" 2>>~/$LOG.err 1>>$Log.log" ; shift
      ;;
      v ) # verbose
       echo TODO   
     ;;
      \? ) echo "Usage: ${FUNCNAME[0]} -sqfv commnd " 
        ;;
    esac
  done
  
  [[ $# == 0 ]] && echo no command provided && return 1
  $s "$@" $r
}

doq() {
 echo ${FUNCNAME[0]} ${FUNCNAME[1]} : "$@"
 BS=$(basename $BASH_SOURCE)
 DLOG=${BS/.*}
 LOG=${GLOBAL_LOG:-$DLOG}
 "$@" 2>> ~/$LOG.err 1>>~/$LOG.log
}

dolog() {
 echo ${FUNCNAME[0]} ${FUNCNAME[1]} : "$@"
 BS=$(basename $BASH_SOURCE)
 DLOG=${BS/.*}
 LOG=${GLOBAL_LOG:-$DLOG}
 sudo "$@" 2>> ~/$LOG.err 1>>~/$LOG.log
}


start_and_enable() {
  log "stating and enabling $1"
  srv=$1
  sudo systemctl enable $srv.service
  sudo systemctl start $srv.service
}

render_bash() {
  template=$1
  if ! [ -z $2 ] ; then 
    source $2
  fi

  eval "cat <<EOF_$$
  $(<$template)
EOF_$$
  " 2> /dev/null
}

update_bash_profile() {
  [[ -z "$1" ]] && echo command is required && return 
  grep -x "$1" ~/.bash_profile > /dev/null 2>&1  && echo this is already in bash profile && return
  echo updating bash profile 
  echo # added by ${BASH_SOURCE} ${FUNCNAME[1]}: ${FUNCNAME[*]}" >> ~/.bash_profile
  echo "$1" >> ~/.bash_profile
  eval "${1}"
}

addpath() {

  [[ -z "$1" ]] && echo must provide a path to add && return

  np=$(readlink -m "$1")
  [[ ! -d "$np" ]] && echo "$np" is not accessible && return

  for p in $(lspath) ; do 
    [[ "$np" == "$p" ]] && echo "$np" is already in path && return
  done

  PATH="${np}:${PATH}"
  export PATH
  if [[ "$2x" == "profilex" ]]; then
     echo "# added by ${BASH_SOURCE} ${FUNCNAME[1]}: ${FUNCNAME[*]}" >> ~/.bash_profile
     echo export PATH=\""${np}:\$PATH"\" >> ~/.bash_profile
  fi
}

rmpath(){
  NPATH=""
  [[ -z "$1" ]] && echo must provide a path to add && return

  rp=$(readlink -m "$1")
  [[ ! -d "$rp" ]] && echo "$rp" is not accessible - trying anyways && rp="$1"
  for p in $(lspath); do
    [[ ! "$p" == "$rp" ]] && NPATH="$NPATH:$p"
  done
  PATH=$(echo $NPATH | sed s'/^:// ; s/:$// ; s/:\+/:/g')
}

lspath(){
  echo "$PATH" | sed 's/:/\n/g'
}

clone_repos() {
  [[ ! -f "$1" ]] && git clone $1 && return
  for repo in $(cat "$1" | cut -d"," -f1); do
    git clone $repo
  done
}

hostgroups() {
  [[ -z "$1" ]] && echo "Usage: ${FUNCNAME[0]} blueprint" && return
  cat "$1" | jq '.host_groups[]|"\(.name) - \(.components[].name)"' 
}

get_vars_from_files() {
  grep -hPo '(\$[^ ]+):-' ${1:-~/hwxctrl/templates/*} | tr -d '{},:-' | sort | uniq
}

rootrun(){
  [[ ! -z $PASSWORD ]] && local pass=${2-$PASSWORD}
  [[ -z $pass ]] && echo "need password to run as root" && return
  [[ -z "$1" ]] && echo "no command to run " && return
  echo "$pass" | su -c "$1" > /dev/null 2>&1
}

myclone() {
  git clone https://github.com/edennuriel/$1
}

gf() {
  grep \(\) ${1}
}

get_sec_key(){
  [[ ! u$(command -v gpg) ]] && echo "gpg is missing" && return
  [[ $(gpg -K | grep sec) ]] && echo "already have security key - returning" && return
  read -p "Path to key? " location
  [[ ! -f "$location" ]] && "File not found" && return
  gpg --import $location
}

sourcegpg() {
  get_sec_key
  local pass="${1:-$PASSWORD}"
  local file="${2:-/home/centos/hwxctrl/refs/enc_env.vars}"
  ([[ -z $pass ]] || [[ -z $file ]]) && echo "Require passphrase and file to source" && return
  
  eval "$(gpg --passphrase "$pass" --no-tty -q -d "$file" )"
}

