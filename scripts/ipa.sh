#set name of instance to ipa.someawsdomain
hostname=$(hostname)
domain=$(hostname -d)

export REALM=${1:-$domain}
export PASSWORD=${2:-admin1234}
export NAME=${4:-$hostname}
export DOMAIN=${3:-$domain}
REALM=${REALM^^}
export IP=$(hostname --ip-address)
echo "IP is ${IP}"
echo "REALM ${REALM} PASSWORD ${PASSWORD} NAME ${NAME} DOMAIN ${DOMAIN}"

sethostname() {
	sudo sh -c "echo ${IP} ${NAME}.${DOMAIN} ${NAME} $(hostname -f) $(hostname -s) >  /etc/hosts"
	sudo sh -c "echo 127.0.0.1 localhost >> /etc/hosts"
	sudo hostnamectl set-hostname ${NAME}.${DOMAIN}
	sudo hostnamectl --transient set-hostname ${NAME}
	sudo hostname ${NAME}.${DOMAIN}
	sudo sh -c "echo 0 >/proc/sys/kernel/hung_task_timeout_secs"
	sudo ethtool -K eth0 tso off
	hostname -f
	cat /etc/hosts
}

configure_resolve_conf() {
	#comment v6
	sudo sed -i 's#\(listen-on-v6*\)#// \1#' /etc/named.conf 
	sudo sed -i '/options {/ a \\tlisten-on {'$IP';};' /etc/named.conf
	# listen only on main ip (not on docker bridge or localhost)
	sudo mv /etc/resolv.conf /etc/resolv.conf.bck
	sudo sh -c "echo nameserver $IP > /etc/resolv.conf"
	sudo sh -c "echo search $domain  >> /etc/resolv.conf"
}

install_ipa() {
	#install packages
	dolog yum install ipa-server ipa-server-dns -y

	#increase entropy
	cat /proc/sys/kernel/random/entropy_avail
	dolog yum install -y rng-tools
	dolog systemctl start rngd
	cat /proc/sys/kernel/random/entropy_avail

	#sometimes needed to avoid server install failing
	sudo systemctl restart dbus
}

setup_ipa() {
	sudo sysctl net.ipv6.conf.all.disable_ipv6=1
	sudo sysctl net.ipv6.conf.lo.disable_ipv6=0
	#sudo echo net.ipv6.conf.lo.disable_ipv6=0 >> /etc/sysctl.conf
	# need to figure out how to do this for other provider - this is static now for openstack field cloud
	export subnet="26.172"
	#install IPA server
	dolog ipa-server-install --realm ${REALM} --domain $DOMAIN \
		--ip-address $IP \
		-a $PASSWORD -p $PASSWORD \
		--setup-dns \
		--forwarder=8.8.8.8 --allow-zone-overlap --no-host-dns \
		--reverse-zone=$subnet.in-addr.arpa. \
		--auto-forwarders --auto-reverse --unattended

	for zone in $(ipa dnszone-find --all | grep "Zone name")
	do
		dolog ipa dnszone-mod $zone --allow-sync-ptr=true
	done
	#change default_ccache_name = FILE:/tmp/krb5cc_%{uid}

}


setup_admins() {
	#kinit as admin
	echo "$PASSWORD" | kinit admin

	# create a new principal to be used for ambari kerberos administration
	ipa user-add hadoopadmin --first=Hadoop --last=Admin --shell=/bin/bash


	# create a new principal to be used for read only ldab bind (whose password will expire in 90 days)
	ipa user-add ldapbind --first=ldap --last=bind

	# create a role and and give it privilege to manage users and services
	ipa role-add hadoopadminrole 
	ipa role-add-privilege hadoopadminrole --privileges="User Administrators" 
	ipa role-add-privilege hadoopadminrole --privileges="Service Administrators"

	#add the hadoopadmin user to the role
	ipa role-add-member hadoopadminrole --users=hadoopadmin
}

setup_users_groups() {
	#do this from file so it is pluggble AD / KDC & IPA
	#create users/groups
	declare -A alluserdds
	for membership in $(cat ../refs/directory.txt)
	do 
		group=${membership/:*}
		users=$(echo ${membership/*:} | tr ',' ' ')
		echo group-add "$group"
		ipa group-add "$group" --desc "Imported group $group" 
		for user in $users
		do 
			echo -- user_add $user --
			yes $PASSWORD | ipa passwd $user 
			ipa user-add $user --first=${user/_*} --last=${user/*_} --shell=/bin/bash
			ipa group-add-member $group --users=$user

		done 
	done

	ipa sudorule-add admin_all_rule
	ipa sudorule-mod admin_all_rule --cmdcat=all --hostcat=all
	ipa sudorule-add-user admin_all_rule --groups=sudoers

	# add noobie to the sudoers user, to enable sudo rules
	ipa group-add-member sudoers --users=noobie
}

setup_truststore() {
	getenforce
	sudo setenforce 0
	echo $PASSWORD | kinit admin 
	sudo mkdir -p /etc/security/certificates/
	sudo cd /etc/security/certificates/
	sudo ipa-getcert request -v -f /etc/security/certificates/host.crt -k /etc/security/certificates/host.key
	sudo ambari-server setup-security --security-option setup-https --import-cert-path=/etc/security/certificates/host.crt --import-key-path=/etc/security/certificates/host.key --api-ssl-port=8444 --pem-password=$PASSWORD --api-ssl=true
}

main() {
	install_ipa
	sethostname
	setup_ipa
	setup_admins
	setup_users_groups
}
