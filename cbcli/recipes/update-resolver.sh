#!/usr/bin/env bash
hostnamectl set-hostname `hostname -f`
cat >/etc/unbound/conf.d/02-ipa.conf<<EOF
forward-zone:
  name: "hortonworks.net"
  forward-addr: 172.26.212.91
EOF
pkill -SIGHUP unbound
