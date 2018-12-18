#!/usr/bin/env bash
# select a method to get secrets...
# simplest...
echo scp secret file to source from your secured environment.
echo '(eg: eden:# scp env.vars centos@enctrl:/tmp)'
read -p "filename to source (eg: /tmp/env.vars): " secrets
[[ ! -z "$secrets" ]] && [[ -f "$secrets" ]] && source "$secrets" #&& rm "$secrets"
cat $secrets
cbadd_cred ~/hwxctrl/templates/ops_cred_prj.json enops

