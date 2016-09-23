#!/bin/sh

set -e

WHITE='\033[1;37m'
NC='\033[0m'

print_for_log() {
    echo -e "${WHITE}$1${NC}"
}

#
# Install _bashrc
#
print_for_log "Linking _bashrc..."

ln -sf "$(pwd)/_bashrc" ~/.bashrc

if [ ! -e "$HOME/.bash_profile" ] ; then
    ln -sf "$(pwd)/_bash_profile" ~/.bash_profile
fi

#
# Install _screenrc
#
print_for_log "Linking _screenrc"

ln -sf "$(pwd)/_screenrc" ~/.screenrc

#
# Install _vimrc
#
print_for_log "Linking _vimrc"

if [ ! -e "$HOME/.vim/bundle" ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

ln -sf "$(pwd)/_vimrc" ~/_vimrc
vim -c "set shortmess+=I" +PluginInstall +qall

(cd ~/.vim/bundle/vimproc/; make)
