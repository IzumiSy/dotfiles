#!/bin/bash
set -Ceu

function execute_rbenv_install() {
  git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
  git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
}

echo "Looks rbenv is not installed yet. Do you want to install it? [Y/n]"
read answer

case $answer in
  no) echo "Skipped nvm set-up."; ;;
  yes|*) execute_rbenv_install; ;;
esac
