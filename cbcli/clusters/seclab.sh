#!/usr/bin/env bash
source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cb.sh
source ~/hwxctrl/scripts/cbcli.sh
cbadd_cred ~/hwxctrl/templates/ops_cred_271.json enops
cd cbcli/recipes
cbadd_recipe ipa-client.sh
cbadd_recipe ambari-mysql.sh
cbadd_recipe secure-ambari-server.sh post-cluster-install
cbadd_recipe updater-resolver.sh
cd ../blueprints
cbadd_blueprint Security_HA_3.0.1_blueprint.json
cd ../clusters
cbadd_mpacks http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/3.2.0.0/tars/hdf_ambari_mp/hdf-ambari-mpack-3.2.0.0-520.tar.gz hdf32
cbadd_mpacks http://public-repo-1.hortonworks.com/HDP-SOLR/hdp-solr-ambari-mp/solr-service-mpack-4.0.0.tar.gz solr
cb cluster create --cli-input-json smesec.json
