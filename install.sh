#!/bin/bash

# Strict error handling
set -euo pipefail

# Set non-interactive mode for package managers
export DEBIAN_FRONTEND=noninteractive
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTO_UPDATE=1
export CI=true

# Global variables
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly DOTFILES_DIR
readonly LOCALE="en_US.UTF-8"
TEMP_FILES=()

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
			if [[ -e "$temp_file" ]]; then
				rm -rf "$temp_file"
			fi
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
	local max_time="${3:-30}"
	local max_retries=3
	local retry=0

	while [[ $retry -lt $max_retries ]]; do
		if curl -fsSL --connect-timeout 10 --max-time "$max_time" "$url" -o "$output"; then
			return 0
		fi
		retry=$((retry + 1))
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
		retry=$((retry + 1))
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

	if ! git -C "$directory" pull --ff-only --quiet; then
		log_error "Failed to update repository in $directory"
		return 1
	fi
}

validate_dotfiles_dir() {
	if [[ ! -d "$DOTFILES_DIR" ]]; then
		log_error "Dotfiles directory not found: $DOTFILES_DIR"
		return 1
	fi

	local required_files=(".zshrc" ".zprofile" ".gitconfig")
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
		# macOS needs no system change: .zshrc exports LANG/LC_ALL. Don't write
		# AppleLocale, it takes values like en_US (not en_US.UTF-8) and would
		# clobber the user's language/region settings.
		log_info "macOS: locale is set per shell by .zshrc, nothing to do"
	elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
		# `locale -a` lists en_US.utf8, not en_US.UTF-8, so compare case- and
		# dash-insensitively or locale-gen would rerun on every install.
		local wanted
		wanted="$(printf '%s' "$LOCALE" | tr '[:upper:]' '[:lower:]' | tr -d '-')"
		if locale -a | tr '[:upper:]' '[:lower:]' | tr -d '-' | grep -qxF "$wanted"; then
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
	# Installs zsh plus base dependencies the rest of this script needs
	# (git for cloning Oh My Zsh / plugins, unzip for the nerd font).
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		local missing=()
		local pkg
		for pkg in zsh git unzip; do
			command_exists "$pkg" || missing+=("$pkg")
		done
		if [[ ${#missing[@]} -eq 0 ]]; then
			log_info "Zsh and base deps already installed"
			return 0
		fi
		log_info "Installing: ${missing[*]}"
		sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq || {
			log_error "Failed to update package list"
			return 1
		}
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}" || {
			log_error "Failed to install: ${missing[*]}"
			return 1
		}
		log_success "Zsh installation completed"
		return 0
	fi

	if command_exists zsh; then
		log_info "Zsh is already installed"
		return 0
	fi

	log_info "Installing Zsh"
	if [[ "$OSTYPE" == "darwin"* ]]; then
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
		# An update failing (offline, local edits) must not abort the install:
		# the existing checkout still works.
		log_info "Updating $plugin_name"
		safe_git_pull "$plugin_dir" || log_warning "Could not update $plugin_name (continuing with existing copy)"
	fi
}

install_zsh_plugins() {
	log_info "Installing/updating Zsh plugins"

	# Core plugins
	install_zsh_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
	install_zsh_plugin "zsh-completions" "https://github.com/zsh-users/zsh-completions"
	install_zsh_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

	log_success "Zsh plugins installation completed"
}

# Write a small real file in $HOME that sources/includes the repo copy, instead of
# symlinking it. Tools that append to ~/.zshrc, ~/.zprofile or ~/.gitconfig (gcloud,
# codex, `git config --global`, ...) then change the stub, not the tracked file.
# Idempotent: an existing stub for this repo path is left alone, so tool additions survive.
write_stub() {
	local target="$1" marker="$2" body="$3"
	if [[ -f "$target" && ! -L "$target" ]] && grep -qF "$marker" "$target"; then
		return 0
	fi
	if [[ -L "$target" ]]; then
		rm "$target" || return 1
	else
		backup_file "$target" || return 1
	fi
	printf '%s\n%s\n' "$marker" "$body" >"$target"
}

link_config_files() {
	log_info "Linking configuration files"

	local marker="# dotfiles-stub: $DOTFILES_DIR (tools may append below; the repo stays clean)"
	write_stub "$HOME/.zshrc" "$marker" "source \"$DOTFILES_DIR/.zshrc\"" || {
		log_error "Failed to write .zshrc stub"
		return 1
	}
	write_stub "$HOME/.zprofile" "$marker" "source \"$DOTFILES_DIR/.zprofile\"" || {
		log_error "Failed to write .zprofile stub"
		return 1
	}
	write_stub "$HOME/.gitconfig" "$marker" "[include]
	path = $DOTFILES_DIR/.gitconfig" || {
		log_error "Failed to write .gitconfig stub"
		return 1
	}
	log_info "Wrote .zshrc, .zprofile and .gitconfig stubs pointing at $DOTFILES_DIR"

	# Coder workspaces (CODER is set there) commit as the work identity. This lands in the
	# ~/.gitconfig stub below the include, so it overrides the tracked [user] without editing it.
	if [[ -n "${CODER:-}" ]]; then
		git config --global user.name "Atif Ali"
		git config --global user.email "atif@coder.com"
		log_info "Git identity set to Atif Ali <atif@coder.com> (Coder workspace)"
	fi

	# Setup SSH signing key for git
	# In a Coder workspace, sign with the user's Coder git SSH key (works without a forwarded
	# agent, so cloud agents can sign too). bin/coder-ssh-sign fetches the private key into
	# tmpfs per signature, so only the public key is written to disk. The same public key must
	# be a GitHub *signing* key.
	if [[ "$OSTYPE" == "linux-gnu"* ]] &&
		[[ -n "${CODER_AGENT_TOKEN:-}" && -n "${CODER_AGENT_URL:-}" ]] && command_exists curl && command_exists jq; then
		# Header via stdin (printf is a builtin), so the token never shows up in the process list.
		if key_json="$(printf 'Coder-Session-Token: %s\n' "$CODER_AGENT_TOKEN" |
			curl -fsS -H @- "$CODER_AGENT_URL/api/v2/workspaceagents/me/gitsshkey")"; then
			mkdir -p "$HOME/.ssh"
			jq -r .public_key <<<"$key_json" >"$HOME/.ssh/id_ed25519.pub"
			git config --global gpg.ssh.program "$DOTFILES_DIR/bin/coder-ssh-sign"
			log_info "Git signing uses bin/coder-ssh-sign (Coder key fetched per signature, not stored)"
		else
			log_warning "Could not fetch Coder git SSH key; commits will fail to sign"
		fi
	fi
	# Otherwise, on Linux with SSH agent forwarding, create public key from agent if not present
	if [[ "$OSTYPE" == "linux-gnu"* ]] && [[ ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
		if command_exists ssh-add && ssh-add -L &>/dev/null; then
			mkdir -p "$HOME/.ssh"
			ssh-add -L | head -1 >"$HOME/.ssh/id_ed25519.pub"
			log_info "Created SSH public key from forwarded agent for git signing"
		fi
	fi

	# On macOS with the 1Password app, sign via its SSH agent (op-ssh-sign). Like the Coder
	# identity above, this lands in the ~/.gitconfig stub, not the tracked .gitconfig. The
	# public key must still be saved to ~/.ssh/id_ed25519.pub (see configure_git_signing_hint).
	local op_sign="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
	if [[ "$OSTYPE" == "darwin"* && -x "$op_sign" ]]; then
		git config --global gpg.ssh.program "$op_sign"
		log_info "Git signing uses 1Password (op-ssh-sign)"
	fi

	# Link mise global config (always — mise itself is installed by this script).
	# It goes into conf.d, not config.toml: `mise use -g` and `mise set -g` write
	# to config.toml, so that has to stay a local file outside this public repo.
	mkdir -p "$HOME/.config/mise/conf.d" || {
		log_error "Failed to create .config/mise/conf.d directory"
		return 1
	}
	# Drop the config.toml symlink earlier versions of this script created.
	if [[ -L "$HOME/.config/mise/config.toml" ]]; then
		rm "$HOME/.config/mise/config.toml" || return 1
	fi
	ln -sf "$DOTFILES_DIR/.config/mise/config.toml" "$HOME/.config/mise/conf.d/dotfiles.toml" || {
		log_error "Failed to link mise config"
		return 1
	}
	log_info "Linked mise config into conf.d/dotfiles.toml"

	# Link .mux/AGENTS.md for AI coding agents
	mkdir -p "$HOME/.mux" || {
		log_error "Failed to create .mux directory"
		return 1
	}
	ln -sf "$DOTFILES_DIR/.mux/AGENTS.md" "$HOME/.mux/AGENTS.md" || {
		log_error "Failed to link .mux/AGENTS.md"
		return 1
	}
	log_info "Linked .mux/AGENTS.md"

	log_success "Configuration files linked successfully"
}

configure_git_signing_hint() {
	local signing_key="$HOME/.ssh/id_ed25519"
	local signing_pub="$HOME/.ssh/id_ed25519.pub"

	if [[ "$(git config --global --get gpg.ssh.program 2>/dev/null)" == *op-ssh-sign ]]; then
		# 1Password holds the private key; only the public key is needed on disk.
		if [[ -f "$signing_pub" ]]; then
			log_info "Git signing via 1Password. Ensure the SSH agent is enabled in 1Password > Settings > Developer."
		else
			log_warning "Git signing via 1Password, but $signing_pub is missing: save your SSH public key there (1Password > the key > copy Public Key), or commits will fail to sign"
		fi
	elif [[ -f "$signing_key" && -f "$signing_pub" ]]; then
		if [[ "$OSTYPE" == "darwin"* ]]; then
			log_info "Git SSH signing key detected. If needed, load it with: ssh-add --apple-use-keychain $signing_key"
		else
			log_info "Git SSH signing key detected. Ensure it is loaded in ssh-agent for signed commits."
		fi
	else
		log_info "Git SSH signing is configured, but no id_ed25519 keypair was found in ~/.ssh"
	fi
}

install_gh_extensions() {
	# Oh My Zsh plugin selection happens dynamically in .zshrc, so the only
	# install-time work left here is the gh extension itself. `gh` is normally
	# provided by mise, which may not be activated in this script's shell, so
	# fall back to `mise exec` (and to the known install path on a first run).
	local gh_cmd=()
	if command_exists gh; then
		gh_cmd=(gh)
	else
		local mise_bin=""
		if command_exists mise; then
			mise_bin="$(command -v mise)"
		elif [[ -x "$HOME/.local/bin/mise" ]]; then
			mise_bin="$HOME/.local/bin/mise"
		fi
		if [[ -n "$mise_bin" ]] && "$mise_bin" which gh >/dev/null 2>&1; then
			gh_cmd=("$mise_bin" exec -- gh)
		else
			log_info "gh not available; skipping gh extension install"
			return 0
		fi
	fi

	log_info "Installing/updating gh extensions"
	local extensions=("dlvhdr/gh-dash")
	local extension extension_name
	for extension in "${extensions[@]}"; do
		extension_name="${extension##*/}"
		extension_name="${extension_name#gh-}"
		if "${gh_cmd[@]}" extension install "$extension" --force >/dev/null 2>&1; then
			log_info "gh extension $extension_name installed/updated"
		else
			log_info "Skipping gh extension $extension_name (may require auth or network)"
		fi
	done
}

install_nerd_font() {
	local font_name="JetBrainsMono"
	local font_type="NerdFontMono"
	local version="3.5.1"
	local version_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/${font_name}.version"

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

	# Skip only when the installed version matches; bumping $version upgrades.
	if [[ -f "${destination}/${font_name}${font_type}-Regular.ttf" ]] &&
		[[ "$(cat "$version_file" 2>/dev/null)" == "$version" ]]; then
		log_info "${font_name}${font_type} ${version} is already installed"
		return 0
	fi

	log_info "Installing ${font_name}${font_type}"
	mkdir -p "$destination" || {
		log_error "Failed to create fonts directory: $destination"
		return 1
	}

	# Download and install font. Use a private temp dir: curl cannot create the
	# parent directory of -o, and a shared /tmp/<version> path may not exist.
	local temp_dir temp_zip
	temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/${font_name}.XXXXXX")" || {
		log_error "Failed to create temporary directory for ${font_name}"
		return 1
	}
	TEMP_FILES+=("$temp_dir")
	temp_zip="$temp_dir/${font_name}.zip"

	# This release is ~130 MB, so the default 30s cap is far too short.
	safe_curl "https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${font_name}.zip" "$temp_zip" 300 || {
		log_error "Failed to download ${font_name}"
		return 1
	}

	# Remove old fonts only now that the download succeeded.
	rm -f "$destination/${font_name}${font_type}-"*.ttf
	unzip -o -q "$temp_zip" -d "$destination" '*.ttf' || {
		log_error "Failed to extract ${font_name}"
		return 1
	}

	mkdir -p "$(dirname "$version_file")" && printf '%s\n' "$version" >"$version_file"

	# Update font cache on Linux
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		fc-cache -f -q || {
			log_warning "Failed to update font cache"
		}
	fi

	log_success "${font_name}${font_type} installation completed"
}

install_coder_symlink() {
	local coder_bin_dir="$HOME/.config/Code/User/globalStorage/coder.coder-remote/bin"
	local coder_link="$HOME/.local/bin/coder"
	local coder_arch=""
	local candidate=""

	if [[ ! -d "$coder_bin_dir/bin" ]]; then
		log_info "Coder remote binary directory not found, skipping coder symlink"
		return 0
	fi

	case "$(uname -m)" in
	arm64 | aarch64) coder_arch="arm64" ;;
	x86_64 | amd64) coder_arch="amd64" ;;
	esac

	local coder_os="linux"
	[[ "$(uname)" == "Darwin" ]] && coder_os="darwin"

	# Prefer the host architecture, then fall back to any available build.
	local arch
	for arch in "$coder_arch" arm64 amd64; do
		if [[ -n "$arch" && -f "$coder_bin_dir/bin/coder-$coder_os-$arch" ]]; then
			candidate="$coder_bin_dir/bin/coder-$coder_os-$arch"
			break
		fi
	done

	if [[ -z "$candidate" ]]; then
		log_info "No matching coder binary found, skipping coder symlink"
		return 0
	fi

	mkdir -p "$HOME/.local/bin" || {
		log_error "Failed to create $HOME/.local/bin"
		return 1
	}

	if [[ -L "$coder_link" ]]; then
		if [[ "$(readlink "$coder_link")" == "$candidate" ]]; then
			log_info "Coder symlink already configured"
			return 0
		fi
	elif [[ -e "$coder_link" ]]; then
		log_warning "Existing non-symlink found at $coder_link, skipping coder symlink"
		return 0
	fi

	ln -sfn "$candidate" "$coder_link" || {
		log_error "Failed to create coder symlink"
		return 1
	}

	log_success "Coder symlink configured"
}

install_mise() {
	local mise_bin
	if ! command_exists mise; then
		log_info "Installing mise"
		curl -fsSL https://mise.run | sh || {
			log_error "Failed to install mise"
			return 1
		}
		mise_bin="$HOME/.local/bin/mise"
	else
		log_info "mise is already installed"
		mise_bin="$(command -v mise)"
	fi

	# Install tools defined in the global config. Run from $HOME so a stray
	# mise.toml in the dotfiles dir doesn't get picked up.
	#
	# Unset GOROOT/GOBIN: some images (e.g. Coder dogfood) export them pinned
	# to a specific Go install. If mise resolves a different Go version, the
	# `go:` backend then builds with mismatched toolchain and stdlib
	# ("compile: version X does not match go tool version Y"). mise sets the
	# correct values itself.
	if [[ -f "$HOME/.config/mise/conf.d/dotfiles.toml" ]]; then
		log_info "Installing tools from mise global config"
		#
		# Not fatal: on Coder dogfood this races the template's chown of
		# /opt/mise at startup and can fail with permission denied even though
		# every tool is installed. The rest of the setup should still finish.
		(cd "$HOME" && unset GOROOT GOBIN && "$mise_bin" install) || {
			log_warning "mise install failed (continuing)"
		}
		# Generate ~/.config/mise/mise.lock so project configs with
		# `locked = true` (e.g. coder/coder/mise.toml) can resolve the
		# globally-defined tools without warnings.
		#
		# --global also locks the system config. On images that ship a
		# root-owned /etc/mise (e.g. Coder dogfood) that write fails and
		# takes our own lockfile down with it, so leave /etc/mise out.
		(cd "$HOME" && MISE_IGNORED_CONFIG_PATHS=/etc/mise "$mise_bin" lock --global) || {
			log_warning "mise lock --global failed (continuing)"
		}
	fi

	log_success "mise installation completed"
}

install_rex() {
	# macOS gets the server from the Rex app.
	[[ "$OSTYPE" == "linux-gnu"* ]] || return 0

	# Rex is optional, so failures here don't abort the rest of the setup.
	local rex_bin="$HOME/.local/bin/rex"
	if [[ -x "$rex_bin" ]]; then
		log_info "Rex is already installed"
	else
		# --user: binary only into ~/.local/bin, no sudo. Preview channel to
		# match the Mac client.
		log_info "Installing Rex"
		curl -fsSL https://pkgs.superlogical.com/rex/install.sh | sh -s -- --user --channel preview || {
			log_warning "Failed to install Rex (continuing)"
			return 0
		}
	fi

	# A client connecting over SSH doesn't start a missing server, so make sure
	# one is up: at boot via systemd where a user manager exists, otherwise
	# start it now (idempotent; containers rerun this on every start).
	if systemctl --user show-environment &>/dev/null; then
		"$rex_bin" server install || log_warning "rex server install failed (continuing)"
	else
		"$rex_bin" server start || log_warning "rex server start failed (continuing)"
	fi

	log_success "Rex setup completed"
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
	configure_git_signing_hint || exit 1
	install_coder_symlink || exit 1
	install_nerd_font || log_warning "Font installation failed (continuing; it is cosmetic)"
	install_mise || exit 1
	install_gh_extensions || exit 1
	install_rex || exit 1

	log_success "Dotfiles installation completed successfully!"
	log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}

# Run main function
main "$@"
