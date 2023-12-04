export ZSH="$HOME/.oh-my-zsh"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR='vim'
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# flyctl
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
compdef _flyctl fly
