#!/bin/bash

set -e

unlink ~/_vimrc
unlink ~/.screenrc
unlink ~/.bashrc
unlink ~/.bash_profile

rm -rf $HOME/.vim

if [[ "$OSTYPE" = "darwin"* ]] ; then
    vscode_config_path="$HOME/Library/Application Support/Code/User"
else
    vscode_config_path="$HOME/.config/Code/User/"
fi
if [ -e "${vscode_config_path}" ] ; then
    unlink "${vscode_config_path}/settings.json"
    unlink "${vscode_config_path}/keybindings.json"
fi
