export ZSH="$HOME/.oh-my-zsh"
export LANG=en_US.UTF-8
export EDITOR='vim'
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-completions)
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $ZSH/oh-my-zsh.sh
