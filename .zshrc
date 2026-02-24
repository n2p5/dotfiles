export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git github gh jj
    aws azure gcloud 
    bun golang python uv
    docker podman kubectl
    pass encode64
    ssh tmux vscode
)

source $ZSH/oh-my-zsh.sh

export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

# --- dotfiles management ---
alias ddot='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# --- custom functions and local overrides ---
[[ -f ~/.shell_functions ]] && source $HOME/.shell_functions

# --- local overrides (not checked in) ---
[[ -f ~/.zshrc.local ]] && source $HOME/.zshrc.local
[[ -f ~/.env ]] && source $HOME/.env