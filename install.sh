#!/bin/sh

# Clone Vundle to use vundle in Vim
if [ ! -e "$HOME/.vim/vundle.git" ] ; then
    git clone https://github.com/gmarik/vundle.git ~/.vim/vundle.git
fi

ln -sf "$(pwd)/_vimrc" ~/_vimrc
ln -sf "$(pwd)/_screenrc" ~/.screenrc
ln -sf "$(pwd)/_bashrc" ~/.bashrc
