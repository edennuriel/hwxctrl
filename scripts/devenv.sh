#!/usr/bin/env bash
home=~/hwxctrl
source $home/scripts/utils.sh

### Development Env ###

install_java_maven() {
  dolog yum install -y java-1.8.0-openjdk-devel
  dolog yum install -y maven
  dolog yum install -y bats
  #git clone https://github.com/sstephenson/bats.git
  #cd bats
  #./install.sh /usr/local
}

install_python() {
  dolog yum install -y epel-release 
  dolog yum install -y python-pip python-devel 
  dolog pip install --upgrade pip

  #install pyenv
  curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash 
  git clone https://github.com/pyenv/pyenv-virtualenvwrapper.git $(pyenv root)/plugins/pyenv-virtualenvwrapper
  addpath ~/.pyenv/bin

  #configure pyenv
  doq pyenv update
  doq pyenv install 2.7.10
  #pyenv install 3.5.0
  doq pyenv global 2.7.10
  doq pip install -U pip
  doq pyenv virtualenv 2.7.10 os
  doq pyenv global os

  update_bash_profile 'eval "$(pyenv init -)"'
  update_bash_profile 'eval "$(pyenv virtualenv-init -)"'
}

install_ruby() {
  dolog yum install -y ruby
  sudo -u $OSUSER gem install bundler
}

install_ruby_dev() {
  dolog yum install -y git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel
  git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
  git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  addpath ~/.rbenv/bin profile
  addpath ~/.rbenv/plugins/ruby-build/bin profile
  update_bash_profile 'eval "$(rbenv init -)"' 
  #>2.2.2 required for hub
  eval "$(rbenv init -)"
  doq rbenv install -v 2.5.1 
  doq rbenv global 2.5.1
  doq gem install bundler
}

install_hub() {
  #install_ruby>2.2.2 and go
  doq go get github.com/github/hub && cd "$GOPATH"/src/github.com/github/hub
  export prefix=~
  doq make install
  update_bash_profile "alias git=~/bin/hub"
}

install_git_crypt() {
  #as root
  git clone https://github.com/AGWA/git-crypt /tmp/gitcrypt && cd /tmp/gitcrypt
  doq make ENABLE_MAN=yes
  doq make ENABLE_MAN=yes install
}
install_perl() {
echo
}

install_go() {
  #yum install -y wget
  export gover=1.10.3
  #curl -Ls  https://dl.google.com/go/go${gover}.linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin go
  dolog wget https://dl.google.com/go/go${gover}.linux-amd64.tar.gz -O /tmp/go.gz
  dolog tar -C /usr/local -xzvf /tmp/go.gz 
  dolog rm /tmp/go.gz
  mkdir -p ~/go/bin
  update_bash_profile "export GOPATH=~/go"
  addpath /usr/local/go/bin profile
  addpath ~/go/bin profile
}

install_tmux() {
  yum -y install gcc kernel-devel make ncurses-devel libevent2-devel > /dev/null 2&>1
  cd /tmp && curl -L https://github.com/tmux/tmux/releases/download/2.7/tmux-2.7.tar.gz | tar xzv && cd /tmp/tmux-2.7
  LDFLAGS="-L/usr/local/lib -Wl,-rpath=/usr/local/lib" ./configure --prefix=/usr/local
  make
  make install
  # pkill tmux
  cd "$(dirname ${BASH_SOURCE[0]})"
  cat > ~/.tmux.conf << EOD
  set-option -g mouse on

  # make scrolling with wheels work
  bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'select-pane -t=; copy-mode -e; send-keys -M'" 
  bind -n WheelDownPane select-pane -t= \; send-keys -M
EOD
}


install_vim8(){
  yes ${password} | sudo passwd root
  sudo yum -y groupinstall "Development tools" 
  sudo yum -y install  ncurses ncurses-devel 
  sudo git clone https://github.com/vim/vim.git /tmp/vim

  rootrun 'cd /tmp/vim && ./configure --prefix=/usr \
       --with-features=huge \
       --enable-multibyte \
       --with-python-config-dir=/usr/lib/python2.7/config \
       --enable-pythoninterp=yes'

  rootrun 'cd /tmp/vim && make -j4 && make install'
  rootrun 'yum -y install sudo'
}

configure_git() {
  git config --global user.name ${1:-edennuriel}
  git config --global user.email ${2:-edennuriel@hotmail.com}
  git config --global  hub.protocol https
  git config --global credential.helper 'cache --timeout 3600'
}
