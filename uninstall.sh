#!/bin/bash
set -e

source ./_misc.sh

unlink ~/_vimrc
unlink ~/.screenrc
unlink ~/.bashrc
unlink ~/.bash_profile

rm -rf $HOME/.vim
