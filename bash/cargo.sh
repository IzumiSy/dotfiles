# For rustlang
if [ -f "$HOME/.cargo/env" ]; then
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
