#!/bin/bash

DOTFILES_DIR="$(realpath "$(dirname "$0")")"
echo "DOTFILES_DIR: $DOTFILES_DIR"

# Set locale
LOCALE="en_US.UTF-8"

# Check if the locale is available
if ! locale -a | grep -qx "$LOCALE"; then
  echo "Locale $LOCALE not found. Generating..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo locale-gen "$LOCALE"
    sudo update-locale LANG="$LOCALE"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    sudo locale-gen "$LOCALE"
    sudo defaults write -g AppleLocale -string "$LOCALE"
  fi
else
  echo "Locale $LOCALE already available."
fi

# Check if Zsh is installed and install it if not
if ! command -v zsh &>/dev/null; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Installing Zsh"
    sudo apt-get update
    sudo apt-get install zsh -y
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install zsh
  fi
else
  echo "Zsh is already installed"
fi

# Set Zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo "Setting Zsh as default shell for $USER"
  sudo chsh -s "$(which zsh)" "$USER"
else
  echo "Zsh is already the default shell"
fi

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing Oh My Zsh"
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh is already installed"
fi

# Define the installation directory for the plugins
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"

# Install Zsh plugins if not already installed otherwise update them
if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
  echo "Installing zsh-autosuggestions"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
else
  echo "Updating zsh-autosuggestions"
  cd "$PLUGINS_DIR/zsh-autosuggestions" && git pull && cd -
fi

if [ ! -d "$PLUGINS_DIR/zsh-completions" ]; then
  echo "Installing zsh-completions"
  git clone https://github.com/zsh-users/zsh-completions "$PLUGINS_DIR/zsh-completions"
else
  echo "Updating zsh-completions"
  cd "$PLUGINS_DIR/zsh-completions" && git pull && cd -
fi

if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGINS_DIR/zsh-syntax-highlighting"
else
  echo "Updating zsh-syntax-highlighting"
  cd "$PLUGINS_DIR/zsh-syntax-highlighting" && git pull && cd -
fi

if command -v nix &>/dev/null; then
  if [ ! -d "$PLUGINS_DIR/nix-zsh-completions" ]; then
    echo "Installing nix-zsh-completions"
    git clone https://github.com/nix-community/nix-zsh-completions.git "$PLUGINS_DIR/nix-zsh-completions"
  else
    echo "Updating nix-zsh-completions"
    cd "$PLUGINS_DIR/nix-zsh-completions" && git pull && cd -
  fi
  if [ ! -d "$PLUGINS_DIR/nix-shell" ]; then
    echo "Installing zsh-nix-shell"
    git clone https://github.com/chisui/zsh-nix-shell.git "$PLUGINS_DIR/nix-shell"
  else
    echo "Updating zsh-nix-shell"
    cd "$PLUGINS_DIR/nix-shell" && git pull && cd -
  fi
else
  echo "Nix is not installed, skipping nix-zsh-completions"
fi

## Link the .zshrc file
if [ -f ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi
echo "Linking .zshrc"
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

## Link the .zprofile file
if [ -f ~/.zprofile ]; then
  mv ~/.zprofile ~/.zprofile.bak
fi
echo "Linking .zprofile"
ln -sf "$DOTFILES_DIR/.zprofile" ~/.zprofile

## Link the .config/nix/nix.conf file
if command -v nix &>/dev/null; then
  mkdir -p ~/.config/nix
  echo "Linking $DOTFILES_DIR/.config/nix/nix.conf to $HOME/.config/nix/nix.conf"
  ln -sf "$DOTFILES_DIR/.config/nix/nix.conf" "$HOME/.config/nix/nix.conf"
else
  echo "Nix is not installed, skipping nix.conf"
fi

## Link the .config/ghostty/config file
if command -v ghostty &>/dev/null || [ -e "$HOME/Applications/Ghostty.app" ]; then
  mkdir -p ~/.config/ghostty
  echo "Linking $DOTFILES_DIR/.config/ghostty/config to $HOME/.config/ghostty/config"
  ln -sf "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config"
else
  echo "Ghostty is not installed, skipping ghostty.conf"
fi

## Set the .gitconfig file
ln -sf "$DOTFILES_DIR/.gitconfig" ~/.gitconfig

# Plugins
## Add brew and macos plugins for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Adding brew and macos plugins for macOS"
  perl -i -pe 's/plugins=\(/plugins=(brew macos /' "$HOME/.zshrc"
fi

## Add nix-shell and nix-zsh-completions plugins for Nix if Nix is installed
if command -v nix &>/dev/null; then
  echo "Adding nix-shell and nix-zsh-completions plugins for Nix"
  perl -i -pe 's/plugins=\(/plugins=(nix-shell nix-zsh-completions /' "$HOME/.zshrc"
fi

if command -v gh &>/dev/null; then
  ## Add gh plugin for GitHub CLI
  echo "Adding gh plugin for GitHub CLI"
  perl -i -pe 's/plugins=\(/plugins=(gh /' "$HOME/.zshrc"
  # Install gh-dash
  gh extension install dlvhdr/gh-dash --force
  # Install gh-copilot
  gh extension install github/gh-copilot --force
  # install gh-act
  gh extension install nektos/gh-act --force
fi

## Add bun plugin for Bun if Bun is installed
if command -v bun &>/dev/null; then
  echo "Adding bun plugin for Bun"
  perl -i -pe 's/plugins=\(/plugins=(bun /' "$HOME/.zshrc"
fi

## Add jfrog plugin for JFrog CLI if JFrog CLI is installed
if command -v jfrog &>/dev/null || command -v jf &>/dev/null; then
  echo "Adding jfrog plugin for JFrog CLI"
  perl -i -pe 's/plugins=\(/plugins=(jfrog /' "$HOME/.zshrc"
fi

# Install HackNerdFont
if [[ "$OSTYPE" == "darwin"* ]]; then
  destination="$HOME/Library/Fonts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Check for headless Linux by looking for the DISPLAY environment variable
  if [ -z "$DISPLAY" ]; then
    echo "Headless Linux detected. Skipping font installation."
    exit 0
  fi
  destination="$HOME/.local/share/fonts"
fi

# Check if the font is already installed
if [ -f "$destination/HackNerdFont-Regular.ttf" ]; then
  echo "HackNerdFont is already installed"
else
  echo "Installing HackNerdFont"
  mkdir -p "$destination"
  rm -f "$destination/HackNerdFont*.ttf"
  curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Hack.zip -o /tmp/Hack.zip
  unzip -o /tmp/Hack.zip -d "$destination" '*.ttf' && rm /tmp/Hack.zip
  # Update the font cache
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    fc-cache -f -v
  fi
fi

# Install macOS specific dependencies
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Installing macOS specific dependencies"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
fi

echo "Dotfiles installation complete!"
