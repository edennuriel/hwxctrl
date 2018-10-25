# hwxctrl
Automated build of a devop controller machine for hwx products

##Objectives
- bootstrap a devop environment for cloudbreak deployment
- provide services for cloudbreak for demos and simple deploys - ad/ldap/kdc/ipa/db/etc... 
- centrlized other provisioning solution like hortonworks-ansible etc..

# workflow #1
create openstack instance
install git and clone https:/github.com/edennuriel/hwxctrl
prepare the environment source ~/hwxctrl/scripts/hwxctrl-setup.sh and install_hwxctrl_simple

manually edit the env.vars for credentials, or run get_sec_key to import a gpg key that can be used to source the encrypted enc_env.vars
add credentials, blueprints and recipes
create cluster


