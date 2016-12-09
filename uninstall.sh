#!/bin/bash
set -ex

unlink ~/_vimrc
unlink ~/.screenrc
unlink ~/.bashrc
unlink ~/.bash_profile

rm -rf $HOME/.vim

set +ex
