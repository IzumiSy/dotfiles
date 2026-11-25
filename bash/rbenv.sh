# Enables rbenv if installed
if command -v rbenv >/dev/null 2>&1; then
  if [ -e "$HOME/.rbenv" ]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
  fi
  eval "$(rbenv init --no-rehash -)"
  (rbenv rehash &) 2> /dev/null # lazy rehashing
  echo "Loaded rbenv"
fi
