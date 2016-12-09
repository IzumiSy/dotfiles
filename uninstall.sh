#!/bin/bash
set -Ceux

unlink "$HOME/_vimrc"
unlink "$HOME/.screenrc"
unlink "$HOME/.bashrc"
unlink "$HOME/.bash_profile"

rm -rf "$HOME/.vim"

set +x
