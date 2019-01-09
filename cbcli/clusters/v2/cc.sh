#!/usr/bin/env bash
source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cb.sh
source ~/hwxctrl/scripts/cbcli.sh
if [[ -z $1 ]] 
then 
	enops="$(cb credential list | jq '..|.Name?|test("enops")')"
	echo "credential enops - $enops"
	[[ "$enops" == "true" ]] ||  source ../../bootstrap.sh
	cbadd_blueprint bp.json
	echo "blue print add rc=$?"
	cbadd_mpack_hdf33
	echo "add hdf32 rc=$?"
	cbadd_mpack_solr7
	echo "add solr rc=$?"
	~/hwxctrl/scripts/prepare_recpies.sh > /dev/null > 2>&null
	echo "prep recepies rc=$?"
fi
pass={$1:-admin1234}
cb cluster create --input-json-param-password=$pass --cli-input-json cc.json
