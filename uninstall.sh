#!/bin/bash

set -e

source ~/_misc.sh

unlink ~/_vimrc
unlink ~/.screenrc
unlink ~/.bashrc
unlink ~/.bash_profile

rm -rf $HOME/.vim

if [ -e "${vscode_config_path}" ] ; then
    unlink "${vscode_config_path}/settings.json"
    unlink "${vscode_config_path}/keybindings.json"
fi
