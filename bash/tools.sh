# Enables nvm if installed
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  echo "Loaded nvm (from $NVM_DIR)"
elif [ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]; then
  . "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
  echo "Loaded nvm (from homebrew)"
fi

# Enables rbenv if installed
if exists rbenv ; then
  if [ -e "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
  fi
  eval "$(rbenv init --no-rehash -)"
  (rbenv rehash &) 2> /dev/null # lazy rehashing
  echo "Loaded rbenv"
fi

# For rustlang
if exists rust ; then
  # NOTE:
  #  If you come across an error related to ssh-agent, put the line below to ~/.cargo/config.
  #  This configuration lets cargo read ~/.ssh/config when downloading packages.
  #
  # ```
  # [net]
  # git-fetch-with-cli = true
  # ```
  #
  source "$HOME/.cargo/env"
fi

# Enables starship if installed
if exists starship ; then
  export STARSHIP_CONFIG=~/.starship.toml
  eval "$(starship init bash)"
fi

# Git completion
if exists brew ; then
  source "$(brew --prefix)/etc/bash_completion.d/git-prompt.sh"
  source "$(brew --prefix)/etc/bash_completion.d/git-completion.bash"
else
  source "/etc/bash_completion.d/git-prompt"
  source "/etc/profile.d/bash_completion.sh"
fi
