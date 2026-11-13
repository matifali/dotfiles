# Environment
export LANGUAGE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR='vim'

# PATH for user-local binaries (mise's binary lives here)
typeset -U path PATH
export PATH="$HOME/.local/bin:$PATH"

# Homebrew (macOS Apple Silicon, macOS Intel, or Linuxbrew)
if [ -d "/opt/homebrew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d "/usr/local/Homebrew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -d "/home/linuxbrew/.linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# mise (manages language runtimes and CLI tools).
# Activated before Oh My Zsh so plugin detection below can find mise-provided
# tools (gh, bun, etc.) via command -v.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

# Plugins. Computed dynamically based on what's installed so the committed
# .zshrc doesn't need install-time mutation.
plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
[[ "$OSTYPE" == "darwin"* ]] && plugins+=(brew macos)
command -v gh >/dev/null 2>&1 && plugins+=(gh)
command -v bun >/dev/null 2>&1 && plugins+=(bun)
(command -v jfrog >/dev/null 2>&1 || command -v jf >/dev/null 2>&1) && plugins+=(jfrog)

source "$ZSH/oh-my-zsh.sh"
# Syntax-highlighting must be sourced after Oh My Zsh.
source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# gh auth alias for Coder workspaces (CODER=true)
if [ "$CODER" = "true" ]; then
  alias gh='GITHUB_TOKEN=$(coder external-auth access-token github) gh'
fi

# Tailscale on macOS
if [ -d "/Applications/Tailscale.app/Contents/MacOS" ]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# Add GOPATH/bin to PATH for binaries from `go install`.
# Append so project tools managed by mise take precedence.
if command -v go >/dev/null 2>&1; then
  path+=("$(go env GOPATH)/bin")
fi

# Local secrets
if [ -f "$HOME/.secrets" ]; then
  source "$HOME/.secrets"
fi

# Optional per-machine overrides.
if [ -f "$HOME/.zshrc.local" ]; then
  source "$HOME/.zshrc.local"
fi
