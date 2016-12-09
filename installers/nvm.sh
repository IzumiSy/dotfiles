#!/bin/bash
set -Ceu

function execute_nvm_install() {
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.3/install.sh | bash
}

echo "Looks nvm is not installed yet. Do you want to install it? [Y/n]"
read answer

case $answer in
  no) echo "Skipped nvm set-up."; ;;
  yes|*) execute_nvm_install; ;;
esac
