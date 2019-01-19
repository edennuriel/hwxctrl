#!/usr/bin/env bash
# select a method to get secrets...
# simplest...
source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cbcli.sh
echo scp secret file to source from your secured environment.
echo '(eg: eden:# scp env.vars.dec enctrl:/tmp)'
read -p "filename to source (eg: /tmp/env.vars.dec): " secrets
[[ -z "$secrets" ]] && secrets=/tmp/env.vars.dec
if [[ -f "$secrets" ]] 
then 
  source "$secrets" #&& rm "$secrets"
  cat $secrets
  cbadd_cred ~/hwxctrl/templates/ops_cred_prj.json enops
fi

