# Preserve the sandbox environment for interactive and child shells.
source /etc/sandbox-persistent.sh
export BASH_ENV=/etc/sandbox-persistent.sh

alias ls='ls --color=auto'
source "$HOME/dotfiles/bash/common.sh"
