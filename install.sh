#!/bin/bash

# Strict error handling
set -euo pipefail

# Set non-interactive mode for package managers
export DEBIAN_FRONTEND=noninteractive
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTO_UPDATE=1
export CI=true

# Global variables
DOTFILES_DIR="$(realpath "$(dirname "$0")")"
readonly DOTFILES_DIR
readonly LOCALE="en_US.UTF-8"
readonly TEMP_FILES=()

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Error handling and cleanup
cleanup() {
	local exit_code=$?
	if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
		log_info "Cleaning up temporary files..."
		for temp_file in "${TEMP_FILES[@]}"; do
			[[ -f "$temp_file" ]] && rm -f "$temp_file"
		done
	fi

	if [[ $exit_code -ne 0 ]]; then
		log_error "Script failed with exit code $exit_code"
		log_error "Installation incomplete. Please check the errors above and re-run the script."
	fi

	exit $exit_code
}

# Set up error trap
trap cleanup EXIT
trap 'log_error "Script interrupted by user"; exit 130' INT TERM

# Utility functions
command_exists() {
	command -v "$1" &>/dev/null
}

safe_curl() {
	local url="$1"
	local output="$2"
	local max_retries=3
	local retry=0

	while [[ $retry -lt $max_retries ]]; do
		if curl -fsSL --connect-timeout 10 --max-time 30 "$url" -o "$output"; then
			return 0
		fi
		((retry++))
		log_warning "Download failed (attempt $retry/$max_retries). Retrying..."
		sleep 2
	done

	log_error "Failed to download from $url after $max_retries attempts"
	return 1
}

safe_git_clone() {
	local repo="$1"
	local destination="$2"
	local max_retries=3
	local retry=0

	while [[ $retry -lt $max_retries ]]; do
		if git clone "$repo" "$destination"; then
			return 0
		fi
		((retry++))
		log_warning "Git clone failed (attempt $retry/$max_retries). Retrying..."
		# Clean up partial clone
		[[ -d "$destination" ]] && rm -rf "$destination"
		sleep 2
	done

	log_error "Failed to clone $repo after $max_retries attempts"
	return 1
}

safe_git_pull() {
	local directory="$1"
	local current_dir
	current_dir="$(pwd)"

	if ! cd "$directory"; then
		log_error "Failed to change directory to $directory"
		return 1
	fi

	if ! git pull; then
		log_error "Failed to update repository in $directory"
		cd "$current_dir"
		return 1
	fi

	cd "$current_dir"
	return 0
}

validate_dotfiles_dir() {
	if [[ ! -d "$DOTFILES_DIR" ]]; then
		log_error "Dotfiles directory not found: $DOTFILES_DIR"
		return 1
	fi

	local required_files=(".zshrc" ".zprofile" ".gitconfig" "Brewfile")
	for file in "${required_files[@]}"; do
		if [[ ! -f "$DOTFILES_DIR/$file" ]]; then
			log_error "Required file not found: $DOTFILES_DIR/$file"
			return 1
		fi
	done

	log_success "Dotfiles directory validation passed"
	return 0
}

backup_file() {
	local file="$1"
	if [[ -f "$file" ]]; then
		local backup
		backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
		if mv "$file" "$backup"; then
			log_info "Backed up $file to $backup"
		else
			log_error "Failed to backup $file"
			return 1
		fi
	fi
}

# Main installation functions
setup_locale() {
	log_info "Setting up locale: $LOCALE"

	if [[ "$OSTYPE" == "darwin"* ]]; then
		# On macOS, check if locale is already set via multiple methods
		local current_locale_global current_locale_lang current_locale_lc_all
		current_locale_global=$(defaults read -g AppleLocale 2>/dev/null || echo "")
		current_locale_lang="${LANG:-}"
		current_locale_lc_all="${LC_ALL:-}"

		# Check if any of the locale settings match what we want
		if [[ "$current_locale_global" == "$LOCALE" ]] ||
			[[ "$current_locale_lang" == "$LOCALE" ]] ||
			[[ "$current_locale_lc_all" == "$LOCALE" ]] ||
			[[ "$(locale | grep LANG= | cut -d= -f2 | tr -d '"')" == "$LOCALE" ]]; then
			log_info "Locale $LOCALE is already configured"
			log_success "Locale setup completed"
			return 0
		fi

		# Check if locale is available in the system
		if locale -a 2>/dev/null | grep -q "$LOCALE"; then
			log_info "Locale $LOCALE is available but not set as default"
			# Try to set without sudo first
			if defaults write -g AppleLocale -string "$LOCALE" 2>/dev/null; then
				log_info "Successfully set locale without sudo"
			else
				log_info "Setting locale to $LOCALE (requires sudo)"
				sudo defaults write -g AppleLocale -string "$LOCALE" || {
					log_warning "Failed to set system locale, but continuing (this is optional)"
				}
			fi
		else
			log_info "Locale $LOCALE may not be available on this macOS system, but continuing (this is optional)"
		fi
	elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
		# On Linux, check if locale is available
		if locale -a | grep -qx "$LOCALE"; then
			log_info "Locale $LOCALE already available"
			log_success "Locale setup completed"
			return 0
		fi

		log_info "Locale $LOCALE not found. Generating..."
		sudo DEBIAN_FRONTEND=noninteractive locale-gen "$LOCALE" || {
			log_error "Failed to generate locale $LOCALE"
			return 1
		}
		sudo DEBIAN_FRONTEND=noninteractive update-locale LANG="$LOCALE" || {
			log_error "Failed to update locale to $LOCALE"
			return 1
		}
	fi

	log_success "Locale setup completed"
}

install_zsh() {
	if command_exists zsh; then
		log_info "Zsh is already installed"
		return 0
	fi

	log_info "Installing Zsh"
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
			log_error "Failed to update package list"
			return 1
		}
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq zsh || {
			log_error "Failed to install Zsh"
			return 1
		}
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		if ! command_exists brew; then
			log_info "Installing Homebrew..."
			NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
				log_error "Failed to install Homebrew"
				return 1
			}
			# Set up Homebrew environment
			if [[ -d "/opt/homebrew" ]]; then
				eval "$(/opt/homebrew/bin/brew shellenv)"
			elif [[ -d "/usr/local/Homebrew" ]]; then
				eval "$(/usr/local/bin/brew shellenv)"
			fi
		fi
		brew install zsh || {
			log_error "Failed to install Zsh via Homebrew"
			return 1
		}
	fi

	log_success "Zsh installation completed"
}

set_default_shell() {
	local zsh_path
	zsh_path="$(command -v zsh)" || {
		log_error "Failed to find Zsh path"
		return 1
	}

	if [[ "$SHELL" == "$zsh_path" ]]; then
		log_info "Zsh is already the default shell"
		return 0
	fi

	log_info "Setting Zsh as default shell for $USER"
	# Use non-interactive shell change
	echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 || true
	sudo chsh -s "$zsh_path" "$USER" || {
		log_warning "Failed to set Zsh as default shell with sudo. Trying usermod..."
		if command_exists usermod; then
			sudo usermod -s "$zsh_path" "$USER" || {
				log_error "Failed to set Zsh as default shell"
				return 1
			}
		else
			log_error "Failed to set Zsh as default shell. Please run 'chsh -s $zsh_path' manually."
			return 1
		fi
	}

	log_success "Default shell set to Zsh"
}

install_oh_my_zsh() {
	if [[ -d "$HOME/.oh-my-zsh" ]]; then
		log_info "Oh My Zsh is already installed"
		return 0
	fi

	log_info "Installing Oh My Zsh"
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
		log_error "Failed to install Oh My Zsh"
		return 1
	}

	log_success "Oh My Zsh installation completed"
}

install_zsh_plugin() {
	local plugin_name="$1"
	local plugin_repo="$2"
	local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
	local plugin_dir="$plugins_dir/$plugin_name"

	if [[ ! -d "$plugin_dir" ]]; then
		log_info "Installing $plugin_name"
		safe_git_clone "$plugin_repo" "$plugin_dir" || {
			log_error "Failed to install $plugin_name"
			return 1
		}
	else
		log_info "Updating $plugin_name"
		safe_git_pull "$plugin_dir" || {
			log_error "Failed to update $plugin_name"
			return 1
		}
	fi
}

install_zsh_plugins() {
	log_info "Installing/updating Zsh plugins"

	# Core plugins
	install_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
	install_zsh_plugin "zsh-completions" "https://github.com/zsh-users/zsh-completions"
	install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

	# Nix-specific plugins
	if command_exists nix; then
		install_zsh_plugin "nix-zsh-completions" "https://github.com/nix-community/nix-zsh-completions.git"
		install_zsh_plugin "nix-shell" "https://github.com/chisui/zsh-nix-shell.git"
	else
		log_info "Nix is not installed, skipping nix-zsh-completions"
	fi

	log_success "Zsh plugins installation completed"
}

link_config_files() {
	log_info "Linking configuration files"

	# Link .zshrc
	backup_file "$HOME/.zshrc"
	ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc" || {
		log_error "Failed to link .zshrc"
		return 1
	}
	log_info "Linked .zshrc"

	# Link .zprofile
	backup_file "$HOME/.zprofile"
	ln -sf "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile" || {
		log_error "Failed to link .zprofile"
		return 1
	}
	log_info "Linked .zprofile"

	# Link .gitconfig
	backup_file "$HOME/.gitconfig"
	ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig" || {
		log_error "Failed to link .gitconfig"
		return 1
	}
	log_info "Linked .gitconfig"

	# Setup SSH signing key for git
	# On Linux with SSH agent forwarding, create public key from agent if not present
	if [[ "$OSTYPE" == "linux-gnu"* ]] && [[ ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
		if command_exists ssh-add && ssh-add -L &>/dev/null; then
			mkdir -p "$HOME/.ssh"
			ssh-add -L | head -1 > "$HOME/.ssh/id_ed25519.pub"
			log_info "Created SSH public key from forwarded agent for git signing"
		fi
	fi

	# Link Nix config if Nix is installed
	if command_exists nix; then
		mkdir -p "$HOME/.config/nix" || {
			log_error "Failed to create .config/nix directory"
			return 1
		}
		ln -sf "$DOTFILES_DIR/.config/nix/nix.conf" "$HOME/.config/nix/nix.conf" || {
			log_error "Failed to link nix.conf"
			return 1
		}
		log_info "Linked nix.conf"
	else
		log_info "Nix is not installed, skipping nix.conf"
	fi

	# Link Ghostty config if Ghostty is installed
	if command_exists ghostty || [[ -e "$HOME/Applications/Ghostty.app" ]]; then
		mkdir -p "$HOME/.config/ghostty" || {
			log_error "Failed to create .config/ghostty directory"
			return 1
		}
		ln -sf "$DOTFILES_DIR/.config/ghostty/config" "$HOME/.config/ghostty/config" || {
			log_error "Failed to link ghostty config"
			return 1
		}
		log_info "Linked ghostty config"
	else
		log_info "Ghostty is not installed, skipping ghostty config"
	fi

	# Link Zed settings if Zed is installed
	if [[ -d "$HOME/.config/zed" ]]; then
		ln -sf "$DOTFILES_DIR/.config/zed/settings.json" "$HOME/.config/zed/settings.json" || {
			log_error "Failed to link Zed settings"
			return 1
		}
		log_info "Linked Zed settings"
	else
		log_info "Zed is not installed, skipping Zed settings"
	fi

	log_success "Configuration files linked successfully"
}

# Helper function for idempotent plugin insertion
add_plugin() {
	local plugin="$1"
	local file="$2"

	if [[ ! -f "$file" ]]; then
		log_error "File not found: $file"
		return 1
	fi

	if ! grep -q "plugins=.*$plugin" "$file"; then
		perl -i -pe "s/plugins=\\(/plugins=($plugin /" "$file" || {
			log_error "Failed to add plugin $plugin to $file"
			return 1
		}
		log_info "Added $plugin plugin"
	else
		log_info "$plugin plugin already present"
	fi
}

configure_plugins() {
	log_info "Configuring plugins"

	# Add macOS-specific plugins
	if [[ "$OSTYPE" == "darwin"* ]]; then
		log_info "Adding macOS-specific plugins"
		add_plugin brew "$HOME/.zshrc"
		add_plugin macos "$HOME/.zshrc"
	fi

	# Add Nix plugins if Nix is installed
	if command_exists nix; then
		log_info "Adding Nix plugins"
		add_plugin nix-shell "$HOME/.zshrc"
		add_plugin nix-zsh-completions "$HOME/.zshrc"
	fi

	# Add GitHub CLI plugins if gh is installed
	if command_exists gh; then
		log_info "Adding GitHub CLI plugins and extensions"
		add_plugin gh "$HOME/.zshrc"

		# Install/upgrade gh extensions with --force to ensure latest versions
		local extensions=("dlvhdr/gh-dash")
		for extension in "${extensions[@]}"; do
			local extension_name="${extension##*/}"         # Extract name after last slash
			local gh_extension_name="${extension_name#gh-}" # Remove gh- prefix if present

			log_info "Installing/updating gh extension: $extension"
			if gh extension install "$extension" --force >/dev/null 2>&1; then
				log_info "gh extension $gh_extension_name installed/updated successfully"
			else
				log_info "Skipping gh extension $gh_extension_name (may require authentication or network access)"
			fi
		done
	fi

	# Add other tool-specific plugins
	if command_exists bun; then
		log_info "Adding Bun plugin"
		add_plugin bun "$HOME/.zshrc"
	fi

	if command_exists jfrog || command_exists jf; then
		log_info "Adding JFrog plugin"
		add_plugin jfrog "$HOME/.zshrc"
	fi

	log_success "Plugin configuration completed"
}

install_nerd_font() {
	font_name="JetBrainsMono"
	font_type="NerdFontMono"
	version="3.4.0"
	log_info "Installing ${font_name}${font_type}"

	local destination
	if [[ "$OSTYPE" == "darwin"* ]]; then
		destination="$HOME/Library/Fonts"
	elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
		# Check for headless Linux
		if [[ -z "${DISPLAY:-}" ]]; then
			log_info "Headless Linux detected. Skipping font installation."
			return 0
		fi
		destination="$HOME/.local/share/fonts"
	else
		log_warning "Unsupported OS for font installation"
		return 0
	fi

	# Check if font is already installed
	if [[ -f "${destination}/${font_name}${font_type}-Regular.ttf" ]]; then
		log_info "${font_name}${font_type} is already installed"
		return 0
	fi

	log_info "Installing ${font_name}${font_type}"
	mkdir -p "$destination" || {
		log_error "Failed to create fonts directory: $destination"
		return 1
	}

	# Clean up old fonts
	rm -f "$destination/${font_name}${font_type}-"*.ttf

	# Download and install font
	local temp_zip="/tmp/${version}/${font_name}.zip"
	TEMP_FILES+=("$temp_zip")

	safe_curl "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${font_name}.zip" "$temp_zip" || {
		log_error "Failed to download ${font_name}"
		return 1
	}

	unzip -o -q "$temp_zip" -d "$destination" '*.ttf' || {
		log_error "Failed to extract ${font_name}"
		return 1
	}

	# Update font cache on Linux
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		fc-cache -f -q || {
			log_warning "Failed to update font cache"
		}
	fi

	log_success "${font_name}${font_type} installation completed"
}

install_macos_dependencies() {
	if [[ "$OSTYPE" != "darwin"* ]]; then
		return 0
	fi

	log_info "Installing macOS-specific dependencies"

	if ! command_exists brew; then
		log_error "Homebrew is not installed"
		return 1
	fi

	brew bundle --file="$DOTFILES_DIR/Brewfile" --quiet || {
		log_error "Failed to install dependencies from Brewfile"
		return 1
	}

	log_success "macOS dependencies installation completed"
}

# Main execution
main() {
	log_info "Starting dotfiles installation"
	log_info "DOTFILES_DIR: $DOTFILES_DIR"

	# Validate environment
	validate_dotfiles_dir || exit 1

	# Run installation steps
	setup_locale || exit 1
	install_zsh || exit 1
	set_default_shell || exit 1
	install_oh_my_zsh || exit 1
	install_zsh_plugins || exit 1
	link_config_files || exit 1
	configure_plugins || exit 1
	install_nerd_font || exit 1
	install_macos_dependencies || exit 1

	log_success "Dotfiles installation completed successfully!"
	log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}

# Run main function
main "$@"
