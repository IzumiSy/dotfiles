# ls override with "eza"
if exists eza ; then
  alias ls="eza"
  alias ll="eza -lh --time-style=long-iso --group-directories-first"
  alias lla="eza -lha --bytes --time-style=long-iso --group-directories-first"
fi

# cat override with "bat"
if exists bat ; then
  alias cat="bat -p --theme=Dracula"
fi

alias tma="tmux attach -t \"$(pwd)\" || tmux new -s \"$(pwd)\""
alias pco='git branch | peco | xargs git checkout'

# Stop processes listening on a TCP port
function killport() {
  local pids pid count=0 status=0
  if [[ $# != 1 || ! $1 =~ ^[0-9]{1,5}$ ]] ||
     (( 10#$1 < 1 || 10#$1 > 65535 )); then
    echo 'Usage: killport <port: 1-65535>' >&2
    return 1
  fi

  pids=$(lsof -tiTCP:"$1" -sTCP:LISTEN) || return
  for pid in $pids; do
    if kill "$pid"; then
      ((count += 1))
    else
      status=$?
    fi
  done
  printf 'Sent SIGTERM to %d process(es) on port %s.\n' "$count" "$1"
  return "$status"
}

# Run the last command set it as the last one in the command history
function hist() {
  CMD=$(history | cut -c 8- | peco)
  history -s $CMD
  echo $CMD
  eval "$CMD"
}
