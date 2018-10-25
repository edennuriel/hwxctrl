#!/usr/bin/env bash

change_host() {
  #get hosts
  #create chanames.json
  ## temp
  cat > /tmp/chnames.json << EOF
{
  "enseclab" : {
      "enseclab-9-1-3.field.hortonworks.net":"enseclab-9-1-3.hortonworks.net",
      "enseclab-9-2-1.field.hortonworks.net":"enseclab-9-2-1.hortonworks.net",
      "enseclab-9-3-0.field.hortonworks.net":"enseclab-9-3-0.hortonworks.net",
      "enseclab-9-4-2.field.hortonworks.net":"enseclab-9-4-2.hortonworks.net"
  }
}
EOF
  sudo ambari-server stop
  yes y |ambari-server update-host-names /tmp/chnames.json
  sudo amabri-server start
}

rmcrt() {
  ipa-getcert stop-tracking -i $(ipa-getcert list | grep -Po "ID \'\K(\d+)")
}

#perl one liner
#turn ipa command to reference 
#cat setup_ipa.sh | perl -ne '$g{"$1"}.="$2," if ($_=~/group-add-member (\w+) --users=(\w+)/);' -e 'END {for $k (keys %g) {$l=$k.":".$g{$k}."\n";$l =~ s/,$//;print $l}}'
#json..
#cat setup_ipa.sh | perl -ne '$g{"$1"}.="$2," if ($_=~/group-add-member (\w+) --users=(\w+)/);' -e 'END {for $k (keys %g) {print "{ \"$k\" } : [ ";$l=$g{$k};chop $l;print "$l ]}\n"}}'

