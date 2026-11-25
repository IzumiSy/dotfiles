# Preserve the sandbox environment for interactive and child shells.
source /etc/sandbox-persistent.sh
export BASH_ENV=/etc/sandbox-persistent.sh

source "$HOME/dotfiles/bash/base.sh"
source "$HOME/dotfiles/bash/nvm.sh"
source "$HOME/dotfiles/bash/tools.sh"
