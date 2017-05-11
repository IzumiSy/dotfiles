#!/bin/bash
set -Ceu

function execute_nvm_install() {
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash
}

tput bold
echo "Looks nvm is not installed yet. Do you want to install it? [yes/no]"
read answer
tput sgr0

case $answer in
  yes) execute_nvm_install; ;;
  no|*) echo "Skipped nvm set-up."; ;;
esac
