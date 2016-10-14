#!/bin/sh

set -e

unlink -v ~/_vimrc
unlink -v ~/.screenrc
unlink -v ~/.bashrc
unlink -v ~/.bash_profile

rm -rf $HOME/.vim

if [[ "$OSTYPE" = "darwin"* ]] ; then
    vscode_config_path="$HOME/Library/Application Support/Code/User"
else
    vscode_config_path="$HOME/.config/Code/User/"
fi

unlink -v "${vscode_config_path}/settings.json"
unlink -v "${vscode_config_path}/keybindings.json"
