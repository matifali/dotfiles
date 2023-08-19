#!/bin/bash

# Check if Zsh is installed, if not, install it
if ! command -v zsh &> /dev/null; then
    echo "Zsh not found. Installing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install zsh -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Check if Homebrew is installed, if not, install it
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Installing..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install zsh
    else
        echo "Unsupported OS. Please install Zsh manually."
        exit 1
    fi
fi

# Make Zsh the default shell
chsh -s $(which zsh)

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# Install zsh-completions
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions" ]; then
    git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-completions
fi

# Install zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Link the .zshrc file
DOTFILES_DIR=$(pwd)
ln -sf $DOTFILES_DIR/.zshrc ~/.zshrc

# Update the .zshrc file based on the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Adding brew and macos plugins for macOS"
    sed -i '' 's/plugins=(git zsh-autosuggestions zsh-completions)/plugins=(git zsh-autosuggestions zsh-completions brew macos)/' .zshrc
fi

# Reload Zsh configuration
source ~/.zshrc

# Reload Zsh configuration
source ~/.zshrc

echo "Dotfiles
