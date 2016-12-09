#!/bin/bash
set -Ceu

#
# Install _bashrc
#
ln -snvf "$(pwd)/_bashrc" "$HOME/.bashrc"

if [ ! -e "$HOME/.bash_profile" ] ; then
    ln -snvf "$(pwd)/_bash_profile" "$HOME/.bash_profile"
fi

#
# Install _screenrc
#
ln -snvf "$(pwd)/_screenrc" "$HOME/.screenrc"

#
# Install _vimrc
#
if [ ! -e "$HOME/.vim/bundle" ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
fi
ln -snvf "$(pwd)/_vimrc" "$HOME/_vimrc"

(set -x; vim +PluginInstall +qall)
(set -x; cd "$HOME/.vim/bundle/vimproc/"; make)

#
# Install nvm and rbenv
#
[ ! -e "$HOME/.nvm" ] && ./installers/nvm.sh
[ ! -e "$HOME/.rbenv" ] && ./installers/rbenv.sh

# Loads .bashrc
clear
(set -x; exec bash --login)
