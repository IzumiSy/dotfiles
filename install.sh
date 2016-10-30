#!/bin/bash
set -e

source ./_misc.sh

print_for_log2 "Start installing dotfiles"

#
# Install _bashrc
#
ln -snvf "$(pwd)/_bashrc" ~/.bashrc

if [ ! -e "$HOME/.bash_profile" ] ; then
    ln -snvf "$(pwd)/_bash_profile" ~/.bash_profile
fi

#
# Install _screenrc
#
ln -snvf "$(pwd)/_screenrc" ~/.screenrc

#
# Install _vimrc
#
if [ ! -e "$HOME/.vim/bundle" ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi
ln -snvf "$(pwd)/_vimrc" ~/_vimrc

print_for_log "Install vim plugins"
vim +PluginInstall +qall

print_for_log "Build vimproc"
(cd ~/.vim/bundle/vimproc/; make)

#
# Link setting/keybindings of VS Code
#
if [ -e "${vscode_config_path}" ] ; then
    ln -snvf "$(pwd)/vscode/settings.json" "${vscode_config_path}/settings.json"
    ln -snvf "$(pwd)/vscode/keybindings.json" "${vscode_config_path}/keybindings.json"
fi

print_for_log2 "Finish installing dotfiles"

# Loads .bashrc
source ~/.bashrc
