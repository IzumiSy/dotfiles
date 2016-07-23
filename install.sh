#!/bin/sh

# To use vundle in Vim
git clone https://github.com/gmarik/vundle.git ~/.vim/vundle.git

ln -sf "$(pwd)/_vimrc" ~/_vimrc
ln -sf "$(pwd)/_screenrc" ~/.screenrc
ln -sf "$(pwd)/_bashrc" ~/.bashrc
