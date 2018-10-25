#!/usr/bin/env bash
source ~/hwxctrl/scripts/utils.sh
source ~/hwxctrl/scripts/cb.sh
source ~/hwxctrl/scripts/cbcli.sh
cbadd_cred ~/hwxctrl/templates/ops_cred_271.json enops
cbadd_blueprint ../blueprints/Security_HA_3.0.1_blueprint.json
cbadd_mpacks http://public-repo-1.hortonworks.com/HDF/centos7/3.x/updates/3.2.0.0/tars/hdf_ambari_mp/hdf-ambari-mpack-3.2.0.0-520.tar.gz hdf32
