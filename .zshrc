export ZSH="$HOME/.oh-my-zsh"
export LANGUAGE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export EDITOR='vim'
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Add .local/bin to the path
export PATH="$HOME/.local/bin:$PATH"

# Aliases
# gh auth alias for Coder workspace i.e. CODER=true
if [ "$CODER" = "true" ]; then
  alias gh='GITHUB_TOKEN=$(coder external-auth access-token github) gh'
fi

# flyctl
if [ -d "$HOME/.fly" ]; then
  export FLYCTL_INSTALL="$HOME/.fly"
  export PATH="$FLYCTL_INSTALL/bin:$PATH"
  compdef _flyctl fly
fi

# tailcale on macOS
if [ -d "/Applications/Tailscale.app/Contents/MacOS" ]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# homebrew
# Add Homebrew for macOS (Apple Silicon and Intel)
if [ -d "/opt/homebrew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d "/usr/local/Homebrew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -d "/home/linuxbrew/.linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Add GNU tools on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # Add GNU getopt to PATH
  if [ -d "$(brew --prefix gnu-getopt)/bin" ]; then
    export PATH="$(brew --prefix gnu-getopt)/bin:$PATH"
  fi
  
  # Add GNU make to PATH
  if [ -d "$(brew --prefix make)/libexec/gnubin" ]; then
    export PATH="$(brew --prefix make)/libexec/gnubin:$PATH"
  fi
fi

# depot CLI
if [ -d "$HOME/.depot" ]; then
  export DEPOT_INSTALL_DIR="$HOME/.depot/bin"
  export PATH="$DEPOT_INSTALL_DIR:$PATH"
fi

# coder binary
# Handle for macOS and Linux
CODER_BIN_DIR="$HOME/.config/Code/User/globalStorage/coder.coder-remote/bin"
if [ -d "$CODER_BIN_DIR" ]; then
  # check if the symbolic link already exists
  if [ ! -L "$HOME/.local/bin/coder" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      # Try both Apple Silicon and Intel macOS
      if [[ -f "$CODER_BIN_DIR/bin/coder-darwin-arm64" ]]; then
        ln -s "$CODER_BIN_DIR/bin/coder-darwin-arm64" "$HOME/.local/bin/coder"
      elif [[ -f "$CODER_BIN_DIR/bin/coder-darwin-amd64" ]]; then
        ln -s "$CODER_BIN_DIR/bin/coder-darwin-amd64" "$HOME/.local/bin/coder"
      fi
    else
      # Linux
      if [[ "$(uname -m)" == "arm64" ]]; then
        ln -s "$CODER_BIN_DIR/bin/coder-linux-arm64" "$HOME/.local/bin/coder"
      else
        ln -s "$CODER_BIN_DIR/bin/coder-linux-amd64" "$HOME/.local/bin/coder"
      fi
    fi
  fi
fi

# Nix
# single-user installation
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  . $HOME/.nix-profile/etc/profile.d/nix.sh
fi
# multi-user installation
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix

# mise (manages language runtimes and CLI tools)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# GO
# Add GOPATH to the PATH so binaries from `go install` are runnable.
# Placed after mise activation since mise provides the `go` binary.
if command -v go >/dev/null 2>&1 && [ -d "$(go env GOPATH)/bin" ]; then
  export PATH="$(go env GOPATH)/bin:$PATH"
fi

# Export Secrets
if [ -f "$HOME/.secrets" ]; then
  source "$HOME/.secrets"
fi