#!/usr/bin/env bash

BASHSOURCE="$BASH_SOURCE"
SOURCEDIR="$( cd "$( dirname "${BASHSOURCE}" )" && pwd )"
yn=""
dbg() {
  echo "$@" | tee -a /tmp/log/rectmp.$$.log
  "$@"
}

source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cb.sh
source ~/hwxctrl/scripts/cbcli.sh

tmp="/tmp/rectmp.$(uuidgen -r)"
mkdir -p "$tmp" > /dev/null 2>&1

for recipe in amb_post amb_pre all_pre
do
  rfile=$tmp/${recipe/_/-}.sh
  dbg cp $SOURCEDIR/recipes_master.sh $rfile
  dbg sed -i s/#$recipe/$recipe/ $rfile
done


update_cb() {
  cbadd_recipe $tmp/amb-pre.sh
  cbadd_recipe $tmp/all-pre.sh
  cbadd_recipe $tmp/amb-post.sh post-ambari-start
}

update_cb

if  [[ $?==0  && "x$1" == "xcc" ]] ; then
  read -N 1 -p "Create default cluster (y/n)?" yn 
  if [[ "x$yn" == "xy" ]] ; then
    echo "($yn) .... creating default cluster (ensmesec)"
    cb cluster create --cli-input-json /home/centos/hwxctrl/cbcli/clusters/smesec.json
  fi
fi

echo removing temp directory "$tmp"
# rm -rf "$tmp"

echo 

