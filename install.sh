#!/bin/bash

# Check if Zsh is installed and install it if not
if ! command -v zsh &>/dev/null; then
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get update
    sudo apt-get install zsh -y
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install zsh
  fi
fi

# Set Zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  sudo chsh -s $(which zsh) $USER
fi

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Define the installation directory for the plugins
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"

# Install Zsh plugins if not already installed otherwise update them
if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions $PLUGINS_DIR/zsh-autosuggestions
else
  cd $PLUGINS_DIR/zsh-autosuggestions && git pull
fi

if [ ! -d "$PLUGINS_DIR/zsh-completions" ]; then
  git clone https://github.com/zsh-users/zsh-completions $PLUGINS_DIR/zsh-completions
else
  cd $PLUGINS_DIR/zsh-completions && git pull
fi

if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $PLUGINS_DIR/zsh-syntax-highlighting
else
  cd $PLUGINS_DIR/zsh-syntax-highlighting && git pull
fi

# Link the .zshrc file
DOTFILES_DIR="$(dirname "$0")" # Set DOTFILES_DIR to the directory where the script is located
# backup existing .zshrc file
if [ -f ~/.zshrc ]; then
  mv ~/.zshrc ~/.zshrc.bak
fi
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc

# Add brew and macos plugins for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Adding brew and macos plugins for macOS"
  perl -i -pe 's/plugins=\(/plugins=(brew macos /' ~/.zshrc
fi

echo "Dotfiles installation complete!"
