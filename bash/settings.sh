# Disable console freezing with Ctrl+S only when stty is available
# (ref: http://www.itmedia.co.jp/help/tips/linux/l0612.html)
[ -t 0 ] && stty stop undef

# Workaround to prevent problem with Byobu that occurs in connecting with Teraterm
export VTE_CJK_WIDTH=1

# Bash shell settings
shopt -s cdspell &> /dev/null;
shopt -s autocd  &> /dev/null;

# Disabled CTRL-D termination
set -o ignoreeof

# Settings for history
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:cd .."
export HISTSIZE=5000

# Settings for ls
export CLICOLOR=1
export LSCOLORS=gxfxcxdxbxegexabagacad

# Setting for screen
export SCREENDIR=$HOME/.screen

# Adds thirdparty binaries
export PATH="$PATH:$HOME/.cargo/bin"    # Rustlang
export PATH="$PATH:$HOME/go/bin"        # Golang
