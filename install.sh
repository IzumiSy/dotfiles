#!/bin/sh

set -e

GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

print_for_log() {
    echo -e "$1$2${NC}"
}

print_for_log GREEN, "Start installing dotfiles"

#
# Install _bashrc
#
print_for_log WHITE, "Linking _bashrc..."

ln -sf "$(pwd)/_bashrc" ~/.bashrc

if [ ! -e "$HOME/.bash_profile" ] ; then
    ln -sf "$(pwd)/_bash_profile" ~/.bash_profile
fi

#
# Install _screenrc
#
print_for_log WHITE, "Linking _screenrc"

ln -sf "$(pwd)/_screenrc" ~/.screenrc

#
# Install _vimrc
#
print_for_log WHITE, "Linking _vimrc"

if [ ! -e "$HOME/.vim/bundle" ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi
ln -sf "$(pwd)/_vimrc" ~/_vimrc

print_for_log WHITE, "Install vim plugins"
vim +PluginInstall +qall

print_for_log WHITE, "Build vimproc"
(cd ~/.vim/bundle/vimproc/; make)

print_for_log GREEN, "Finish installing dotfiles"
