export ZSH="$HOME/.oh-my-zsh"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR='vim'
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
