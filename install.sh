#!/bin/sh

# Clone Vundle to use vundle in Vim
if [ ! -e "$HOME/.vim/bundle" ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

if [ ! -e "$HOME/.bash_profile" ] ; then
    ln -sf "$(pwd)/_bash_profile" ~/.bash_profile
fi

ln -sf "$(pwd)/_vimrc" ~/_vimrc
ln -sf "$(pwd)/_screenrc" ~/.screenrc
ln -sf "$(pwd)/_bashrc" ~/.bashrc

# Install plugins
vim +PluginInstall +qall

# Build vimproc
(cd ~/.vim/bundle/vimproc/; make)
