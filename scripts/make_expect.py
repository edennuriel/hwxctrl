#!/usr/bin/python
import sys,re,logging
startinter=["Save settings",".*"]
stopinter=["Review Settings"]
skip="off"
standalone=None

logging.basicConfig(filename='makeexpect.log',level=logging.DEBUG)

def log(msg):
  logging.debug(msg)

default_re=re.compile(".*\(([^\)]+)\).*")
options_re=re.compile(".*\[([^\]]+)\].*")
question_re=re.compile("([^\[\(]+)")

def parse(regex,data):
  parsed=regex.match(data)
  if parsed:
    #log( parsed.group(1))
    return parsed.group(1)
  else:
    #log ("No groups for input ")
    return ""

expect_commands="""set send_slow {10 0.01}
spawn ambari-server setup-ldap --ldap-force-setup --ambari-admin-password=$env(PASSWORD) --ambari-admin-username=$env(ADMIN)
"""

for line in sys.stdin:
  line=line.strip()
  if len(stopinter) >0 and re.match(stopinter[0],line):
    skip="on"
    stopinter.pop(0)
  if len(startinter) >0 and re.match(startinter[0],line):
    skip="off"
    startinter.pop(0)

  if skip=="off":
    question,sep,answer = line.partition(":")
    #log ("*** Question: {}".format(question))
    options=parse(options_re,question)
    default=parse(default_re,question)
    question=parse(question_re,question)
    if answer is None or answer=="":
      answer=default
      log("replaceing empty enswer with {}".format(default))
    # does not work with variable, only doc when wrting to exp file
    answer=answer.strip()
    expect_commands += ("\n  ### {} ###".format(line))
    expect_commands +="\n  expect \"{}\"\n  send -s \"{}\\r\"".format(question,answer)
    log ( "line: {}\n skip :{}\n question: {}\n options: {}\n default: {}\n answer: \"{}\"\n".format(line,skip,question,options,default,answer))
  else:
    log ("....skipping {}".format(line))

expect_commands +="\nexpect eof"
if standalone is not None:
  print '#!/usr/bin/env bash'

print """
ambari_ldap_setup() {
  [[ -z $(rpm -qa | grep expect) ]] && yum install -y expect > /dev/null 2>&1
  PASSWORD=${1:-admin1234}
  ADMIN=${2:-admin}
  read -r -d '' exp_cmds <<'EOD' 
"""
print (expect_commands)
print """EOD
  # echo expect -c "${exp_cmds//$'\\n'/;}"
  read -r -d '' exp_cmd_no_comments <<< "$(echo "$exp_cmds" | grep -v '#')"
  exp_cmd_no_comments="${exp_cmd_no_comments//$'\\n'/;};"
  expect -c  "$exp_cmd_no_comments"
}

ambari_ldap_sync() {
  ambari-server sync-ldap --all --ldap-sync-admin-name=$ADMIN --ldap-sync-admin-password=$PASSWORD
}

"""
