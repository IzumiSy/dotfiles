# Base interactive Bash settings for the host and Pi sandbox.

# Disable console freezing with Ctrl+S only when stty is available
# (ref: http://www.itmedia.co.jp/help/tips/linux/l0612.html)
[ -t 0 ] && stty stop undef

# Workaround to prevent problem with Byobu that occurs in connecting with Teraterm
export VTE_CJK_WIDTH=1

# Bash shell settings
shopt -s cdspell
shopt -s autocd 2>/dev/null || true

# Disabled CTRL-D termination
set -o ignoreeof

# Settings for history
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:cd .."
export HISTSIZE=5000

# Settings for ls
export CLICOLOR=1
export LSCOLORS=gxfxcxdxbxegexabagacad

# Hostname, time, and working directory without an external prompt tool.
export PS1='\[\e[1;34m\]\h\[\e[0m\] \[\e[1;32m\][\t]\[\e[0m\] \[\e[1m\]\w\[\e[0m\] \$ '

# Basics
alias x='exit'
alias c='clear'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ls='ls --color=auto'
alias ll='ls -lh'
alias lla='ls -lha'

# Git command aliases
alias gad='git add . && gs'
alias gadi='git add -i'
function gd() {
  local unstaged reply
  unstaged=$(git ls-files --modified --others --exclude-standard -- .) || return
  if [[ -n $unstaged ]]; then
    if read -r -p 'Unstaged files found. Run git add -N .? [y/N] ' reply &&
       [[ $reply =~ ^[yY]([eE][sS])?$ ]]; then
      git add -N . || return
    fi
  fi
  git diff HEAD "$@"
}
alias gcm='git commit -m'
alias gch='git checkout'
alias glo='git log --oneline --decorate --graph -15'
alias gs='git status --short'
alias gpl='git pull --rebase origin $(__get_branch_name)'
alias gcmb="git branch --merged | grep -vE '^\*|master$|develop$' | xargs -I % git branch -d %"
alias gpo='check_protecting_branch && git push -u origin $(__get_branch_name)'
alias gpof='check_protecting_branch && git push -u origin $(__get_branch_name) --force-with-lease --force-if-includes'

# Check if the current branch to operate is protected or not
function check_protecting_branch() {
  PROTECTING_BRANCH=(
    "master"
    "develop"
    "main"
  )

  for branch in "${PROTECTING_BRANCH[@]}"; do
    if [[ "$branch" = "$(__get_branch_name)" ]] ; then
      echo "Operation to the current branch is protected"
      return 1
    fi
  done
}

function __get_branch_name() {
  git branch | grep "*" | cut -d ' ' -f 2
}
