#!/bin/bash

DOTFILES_DIR="$(realpath "$(dirname "$0")")"
echo "DOTFILES_DIR: $DOTFILES_DIR"

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
  sudo chsh -s $(which zsh) $USER
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
  git clone https://github.com/zsh-users/zsh-autosuggestions $PLUGINS_DIR/zsh-autosuggestions
else
  echo "Updating zsh-autosuggestions"
  cd $PLUGINS_DIR/zsh-autosuggestions && git pull
fi

if [ ! -d "$PLUGINS_DIR/zsh-completions" ]; then
  echo "Installing zsh-completions"
  git clone https://github.com/zsh-users/zsh-completions $PLUGINS_DIR/zsh-completions
else
  echo "Updating zsh-completions"
  cd $PLUGINS_DIR/zsh-completions && git pull
fi

if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  echo "Installing zsh-syntax-highlighting"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $PLUGINS_DIR/zsh-syntax-highlighting
else
  echo "Updating zsh-syntax-highlighting"
  cd $PLUGINS_DIR/zsh-syntax-highlighting && git pull
fi

# Link the .zshrc file
# backup existing .zshrc file
if [ -f ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi
echo "Linking .zshrc"
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

# Link the .zprofile file
# backup existing .zprofile file
if [ -f ~/.zprofile ]; then
  mv ~/.zprofile ~/.zprofile.bak
fi
echo "Linking .zprofile"
ln -sf "$DOTFILES_DIR/.zprofile" ~/.zprofile

# Link the .config/nix/nix.conf file
if command -v nix &>/dev/null; then
  echo "Linking nix.conf"
  mkdir -p ~/.config/nix
  ln -sf "$DOTFILES_DIR/.config/nix/nix.conf" ~/.config/nix/nix.conf
else
  echo "Nix is not installed, skipping nix.conf"
  exit 1
fi

# Link the .config/ghostty/ghostty.conf file
mkdir -p ~/.config/ghostty
ln -sf "$DOTFILES_DIR/.config/ghostty/ghostty.conf" ~/.config/ghostty/ghostty.conf

# Add brew and macos plugins for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Adding brew and macos plugins for macOS"
  perl -i -pe 's/plugins=\(/plugins=(brew macos /' ~/.zshrc
fi

# Set the .gitconfig file
ln -sf "$DOTFILES_DIR/.gitconfig" ~/.gitconfig

echo "Dotfiles installation complete!"
