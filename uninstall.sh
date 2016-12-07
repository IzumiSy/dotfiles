#!/bin/bash
set -e

unlink ~/_vimrc
unlink ~/.screenrc
unlink ~/.bashrc
unlink ~/.bash_profile

(set -x ; rm -rf $HOME/.vim)
