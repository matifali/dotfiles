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

# Add /usr/local/go to the path if it exists
if [ -d "/usr/local/go" ]; then
  export PATH="/usr/local/go/bin:$PATH"
fi

# Aliases
# gh auth alias for Coder workspace i.e. CODER=true
if [ "$CODER" = "true" ]; then
  alias gh='GITHUB_TOKEN=$(coder external-auth access-token github) gh'
fi

# bun
if [ -d "$HOME/.bun" ]; then
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  # bun completions
  [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
fi

# pnpm
if [ -d "$HOME/.local/share/pnpm" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
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

  # Add Node.js 20 to PATH
  if [ -d "$(brew --prefix node@20)/bin" ]; then
    export PATH="$(brew --prefix node@20)/bin:$PATH"
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

# GO
# Add GOPATH to the PATH
if [ -d "$(go env GOPATH)/bin" ]; then
  export PATH="$(go env GOPATH)/bin:$PATH"
fi

# Export Secrets
if [ -f "$HOME/.secrets" ]; then
  source "$HOME/.secrets"
fi