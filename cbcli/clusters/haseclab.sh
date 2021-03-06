#!/usr/bin/env bash
source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cb.sh
source ~/hwxctrl/scripts/cbcli.sh
if [[ -z $1 ]] 
then 
	source ../bootstrap.sh
	cd ../blueprints
	cbadd_blueprint Security_HA_3.0.1_blueprint.json
	cd ../clusters
	cbadd_mpacks http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/3.2.0.0/tars/hdf_ambari_mp/hdf-ambari-mpack-3.2.0.0-520.tar.gz hdf32
	cbadd_mpacks http://public-repo-1.hortonworks.com/HDP-SOLR/hdp-solr-ambari-mp/solr-service-mpack-4.0.0.tar.gz solr7
	../../scripts/prepare_recpies.sh
fi

cb cluster create --cli-input-json smesec29v1.json
