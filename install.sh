#!/bin/sh

set -e

GREEN='\033[0;32m'
WHITE='\033[1;37m'
NC='\033[0m'

print_for_log() {
    printf "${WHITE}$1${NC}\n"
}

print_for_log2() {
    printf "${GREEN}$1${NC}\n"
}

print_for_log2 "Start installing dotfiles"

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

print_for_log "Install vim plugins"
vim +PluginInstall +qall

print_for_log "Build vimproc"
(cd ~/.vim/bundle/vimproc/; make)

#
# Link setting/keybindings of VS Code
#
print_for_log "Linking VSCode settings/keybindings"

if [ "$OSTYPE" = "darwin"* ] ; then
    vscode_config_path="$HOME/Library/Application Support/Code/User"
else
    vscode_config_path="$HOME/.config/Code/User/"
fi

ln -sf "$(pwd)/Code/settings.json" "${vscode_config_path}/settings.json"
ln -sf "$(pwd)/Code/keybindings.json" "${vscode_config_path}/keybindings.json"

print_for_log2 "Finish installing dotfiles"

