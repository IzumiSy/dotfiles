source /etc/sandbox-persistent.sh
export BASH_ENV="$HOME/.bashrc"

# The fixed npm prefix conflicts with nvm.
unset NPM_CONFIG_PREFIX
# Startup output must not contaminate non-interactive command results.
source "$HOME/dotfiles/bash/nvm.sh" >/dev/null

if [[ $- == *i* ]]; then
  source "$HOME/dotfiles/bash/base.sh"
  source "$HOME/dotfiles/bash/tools.sh"
fi
