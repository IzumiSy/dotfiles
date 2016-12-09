#!/bin/bash
set -Ceu

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

set -x
vim +PluginInstall +qall
(cd ~/.vim/bundle/vimproc/; make)

# Loads .bashrc
exec bash --login

set +x
