#!/usr/bin/env bash

# Cross-Platform Shell Installer Script
# Configures a premium Zsh environment with Zoxide, Fzf, zsh-autosuggestions, and zsh-syntax-highlighting.
# Supported OSs: macOS, Ubuntu/Debian, Arch Linux.

# Exit immediately if a pipeline returns a non-zero status
set -o pipefail

# Color codes for premium terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}${BOLD}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}${BOLD}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}${BOLD}[ERROR]${NC} $1"
}

# Print beautiful header
print_header() {
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo -e "${CYAN}${BOLD}       PREMIUM SHELL SETUP & INSTALLER            ${NC}"
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo ""
}

# Ask for user confirmation
confirm() {
  local prompt_msg="$1"
  local response
  echo -ne "${YELLOW}${BOLD}[CONFIRM]${NC} ${prompt_msg} (y/N): "
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# Detect operating system
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"ubuntu"* || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
      OS="ubuntu"
    elif [[ "$ID" == "arch" || "$ID_LIKE" == *"arch"* ]]; then
      OS="arch"
    else
      OS="unknown"
    fi
  else
    OS="unknown"
  fi
}

# macOS Installation Flow
install_macos() {
  log_info "Checking package requirements on macOS..."
  if ! command -v brew >/dev/null 2>&1; then
    if confirm "Homebrew not found. Install Homebrew?"; then
      log_info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      
      # Configure Homebrew path dynamically for current session
      if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    else
      log_warning "Homebrew installation skipped. Proceeding without Homebrew..."
      echo ""
    fi
  else
    log_success "Homebrew is already installed."
  fi

  # Skip Homebrew auto-updates for faster individual package installation
  export HOMEBREW_NO_AUTO_UPDATE=1

  log_info "Checking packages for installation..."
  for pkg in zsh zoxide fzf git curl neovim tmux starship; do
    local status=""
    local cmd="$pkg"
    if [ "$pkg" = "neovim" ]; then
      cmd="nvim"
    fi
    if command -v "$cmd" >/dev/null 2>&1; then
      status=" (currently installed)"
    fi
    if confirm "Install/upgrade package '$pkg'$status?"; then
      log_info "Installing/upgrading '$pkg'..."
      brew install "$pkg"
    else
      log_info "Skipped package '$pkg'."
    fi
  done

  # Check and install Ghostty terminal (Homebrew Cask)
  local ghostty_status=""
  if command -v ghostty >/dev/null 2>&1 || [ -d "/Applications/Ghostty.app" ]; then
    ghostty_status=" (currently installed)"
  fi
  if confirm "Install/upgrade Ghostty terminal$ghostty_status?"; then
    log_info "Installing/upgrading Ghostty..."
    brew install --cask ghostty
  else
    log_info "Skipped Ghostty terminal."
  fi
}

# Ubuntu/Debian Installation Flow
install_ubuntu() {
  log_info "Updating package lists..."
  sudo apt-get update -y

  for pkg in zsh fzf git curl neovim tmux; do
    local status=""
    local cmd="$pkg"
    if [ "$pkg" = "neovim" ]; then
      cmd="nvim"
    fi
    if command -v "$cmd" >/dev/null 2>&1; then
      status=" (currently installed)"
    fi
    if confirm "Install/upgrade package '$pkg'$status?"; then
      log_info "Installing/upgrading '$pkg'..."
      sudo apt-get install -y "$pkg"
    else
      log_info "Skipped package '$pkg'."
    fi
  done

  # Install zoxide
  local zoxide_status=""
  if command -v zoxide >/dev/null 2>&1; then
    zoxide_status=" (currently installed)"
  fi
  if confirm "Install/upgrade zoxide$zoxide_status?"; then
    if apt-cache show zoxide >/dev/null 2>&1; then
      log_info "Installing zoxide via apt-get..."
      sudo apt-get install -y zoxide
    else
      log_warning "zoxide not found in apt repositories. Installing via official installation script..."
      echo ""
      curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
      export PATH="$HOME/.local/bin:$PATH"
    fi
  else
    log_info "Skipped zoxide."
  fi

  # Install starship
  local starship_status=""
  if command -v starship >/dev/null 2>&1; then
    starship_status=" (currently installed)"
  fi
  if confirm "Install/upgrade starship$starship_status?"; then
    log_info "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
  else
    log_info "Skipped starship."
  fi

  # Install Ghostty terminal (Snap / apt)
  local ghostty_status=""
  if command -v ghostty >/dev/null 2>&1; then
    ghostty_status=" (currently installed)"
  fi
  if confirm "Install/upgrade Ghostty terminal$ghostty_status?"; then
    if command -v snap >/dev/null 2>&1; then
      log_info "Installing Ghostty terminal via snap..."
      sudo snap install ghostty
    elif apt-cache show ghostty >/dev/null 2>&1; then
      log_info "Installing Ghostty terminal via apt..."
      sudo apt-get install -y ghostty
    else
      log_warning "Ghostty terminal is not available in snap or apt repositories for this version of Ubuntu."
      echo ""
    fi
  else
    log_info "Skipped Ghostty terminal."
  fi
}

# Arch Linux Installation Flow
install_arch() {
  for pkg in zsh zoxide fzf git curl neovim tmux starship ghostty; do
    local status=""
    local cmd="$pkg"
    if [ "$pkg" = "neovim" ]; then
      cmd="nvim"
    fi
    if command -v "$cmd" >/dev/null 2>&1; then
      status=" (currently installed)"
    fi
    if confirm "Install/upgrade package '$pkg'$status?"; then
      log_info "Installing/upgrading '$pkg'..."
      sudo pacman -Sy --needed --noconfirm "$pkg"
    else
      log_info "Skipped package '$pkg'."
    fi
  done
}

# Clone Zsh Plugins from GitHub
setup_plugins() {
  local plugin_dir="$HOME/.zsh/plugins"
  log_info "Setting up custom Zsh plugins in $plugin_dir..."
  mkdir -p "$plugin_dir"

  # zsh-autosuggestions
  local status_autosuggestions=""
  if [ -d "$plugin_dir/zsh-autosuggestions" ]; then
    status_autosuggestions=" (currently installed)"
  fi
  if confirm "Setup/update Zsh plugin 'zsh-autosuggestions'$status_autosuggestions?"; then
    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
      log_info "Cloning zsh-autosuggestions..."
      git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
    else
      log_success "zsh-autosuggestions is already cloned. Pulling latest updates..."
      git -C "$plugin_dir/zsh-autosuggestions" pull
    fi
  else
    log_info "Skipped 'zsh-autosuggestions' plugin."
  fi
  echo ""

  # zsh-syntax-highlighting
  local status_syntax=""
  if [ -d "$plugin_dir/zsh-syntax-highlighting" ]; then
    status_syntax=" (currently installed)"
  fi
  if confirm "Setup/update Zsh plugin 'zsh-syntax-highlighting'$status_syntax?"; then
    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then
      log_info "Cloning zsh-syntax-highlighting..."
      git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_dir/zsh-syntax-highlighting"
    else
      log_success "zsh-syntax-highlighting is already cloned. Pulling latest updates..."
      git -C "$plugin_dir/zsh-syntax-highlighting" pull
    fi
  else
    log_info "Skipped 'zsh-syntax-highlighting' plugin."
  fi
  echo ""

  # fzf-tab
  local status_fzftab=""
  if [ -d "$plugin_dir/fzf-tab" ]; then
    status_fzftab=" (currently installed)"
  fi
  if confirm "Setup/update Zsh plugin 'fzf-tab'$status_fzftab?"; then
    if [ ! -d "$plugin_dir/fzf-tab" ]; then
      log_info "Cloning fzf-tab..."
      git clone https://github.com/Aloxaf/fzf-tab "$plugin_dir/fzf-tab"
    else
      log_success "fzf-tab is already cloned. Pulling latest updates..."
      git -C "$plugin_dir/fzf-tab" pull
    fi
  else
    log_info "Skipped 'fzf-tab' plugin."
  fi
}

# Configure .zshrc in an idempotent way
configure_zshrc() {
  local zshrc="$HOME/.zshrc"

  if [ ! -f "$zshrc" ]; then
    log_info "Creating a new .zshrc file..."
    touch "$zshrc"
  else
    local backup="${zshrc}.bak_$(date +%Y%m%d_%H%M%S)"
    log_info "Existing .zshrc found. Backing up to $backup..."
    cp "$zshrc" "$backup"
  fi

  log_info "Updating .zshrc configuration..."

  # Define the configurations block to insert
  local config_block
  config_block=$(cat << 'EOF'

# >>> installer-setup start >>>
# Setup Zsh Plugins
if [ -f "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  source "$HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if [ -f "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]; then
  source "$HOME/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi

# Setup Zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Setup Fzf
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
  else
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
  fi
fi

# Setup Starship Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
# <<< installer-setup end <<<
EOF
  )

  # Check if our block is already present in .zshrc
  if grep -q "# >>> installer-setup start >>>" "$zshrc"; then
    log_info "Updating existing configuration block in .zshrc..."
    local temp_file
    temp_file=$(mktemp)

    # Strip existing block and write to temp file
    awk '/# >>> installer-setup start >>>/{flag=1;next}/# <<< installer-setup end <<</{flag=0;next}!flag' "$zshrc" > "$temp_file"

    # Append new block
    echo "$config_block" >> "$temp_file"
    mv "$temp_file" "$zshrc"
  else
    log_info "Appending configuration block to .zshrc..."
    # Ensure there's a trailing newline before appending
    [ -s "$zshrc" ] && [ -n "$(tail -c1 "$zshrc" 2>/dev/null)" ] && echo "" >> "$zshrc"
    echo "$config_block" >> "$zshrc"
  fi

  log_success ".zshrc successfully configured!"
}

# Change default shell to Zsh
change_shell() {
  local target_shell
  target_shell=$(command -v zsh)

  if [ -z "$target_shell" ]; then
    log_error "Zsh binary not found. Cannot change default shell."
    return 1
  fi

  local current_shell=""
  if [[ "$OSTYPE" == "darwin"* ]]; then
    current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
  fi
  if [ -z "$current_shell" ] && command -v getent >/dev/null 2>&1; then
    current_shell=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
  fi
  if [ -z "$current_shell" ]; then
    current_shell="$SHELL"
  fi

  # Check if the current shell is already Zsh
  if [[ "$current_shell" != *zsh ]]; then
    log_info "Your current default login shell is: $current_shell"
    log_info "Changing default login shell to Zsh ($target_shell)..."
    log_warning "This action may request your password."
    echo ""
    if chsh -s "$target_shell"; then
      log_success "Default login shell changed to Zsh successfully!"
    else
      log_error "Could not automatically change default login shell."
      log_warning "To change it manually, please run:"
      log_warning "  chsh -s $target_shell"
      echo ""
    fi
  else
    log_success "Zsh ($current_shell) is already your default login shell."
  fi
}

# Clone dotfiles repo and setup neovim + ghostty configs
setup_dotfiles() {
  local has_dotfiles=""
  if [ -d "$HOME/.config/nvim" ] || [ -d "$HOME/.config/ghostty" ]; then
    has_dotfiles=" (configs exist)"
  fi
  if confirm "Clone dotfiles repository and configure Neovim/Ghostty$has_dotfiles?"; then
    log_info "Setting up Neovim and Ghostty configurations from dotfiles repository..."
    local config_dir="$HOME/.config"
    mkdir -p "$config_dir"

    local temp_dir
    temp_dir=$(mktemp -d)

    log_info "Cloning dotfiles repository..."
    if git clone https://github.com/sanjay-np/dotfiles "$temp_dir" >/dev/null 2>&1; then
      
      # Setup Neovim Config
      if [ -d "$temp_dir/nvim" ]; then
        if [ -d "$config_dir/nvim" ]; then
          local nvim_backup="${config_dir}/nvim.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing Neovim configuration found. Backing up to $nvim_backup..."
          mv "$config_dir/nvim" "$nvim_backup"
        fi
        log_info "Copying Neovim configuration to $config_dir/nvim..."
        cp -R "$temp_dir/nvim" "$config_dir/nvim"
        log_success "Neovim configuration successfully set up!"
      else
        log_warning "No 'nvim' directory found in dotfiles repository."
        echo ""
      fi

      # Setup Ghostty Config
      if [ -d "$temp_dir/ghostty" ]; then
        if [ -d "$config_dir/ghostty" ]; then
          local ghostty_backup="${config_dir}/ghostty.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing Ghostty configuration found. Backing up to $ghostty_backup..."
          mv "$config_dir/ghostty" "$ghostty_backup"
        fi
        log_info "Copying Ghostty configuration to $config_dir/ghostty..."
        cp -R "$temp_dir/ghostty" "$config_dir/ghostty"
        log_success "Ghostty configuration successfully set up!"
      else
        log_warning "No 'ghostty' directory found in dotfiles repository."
        echo ""
      fi

      rm -rf "$temp_dir"
    else
      log_error "Failed to clone dotfiles repository. Skipping config setups."
      rm -rf "$temp_dir"
    fi
  else
    log_info "Skipped dotfiles configuration setup."
  fi
}

# Install opencode.ai via curl script
install_opencode() {
  local status=""
  if command -v opencode >/dev/null 2>&1; then
    status=" (currently installed)"
  fi
  if confirm "Install/upgrade opencode.ai$status?"; then
    log_info "Installing opencode.ai via official curl script..."
    if curl -fsSL https://opencode.ai/install | bash; then
      log_success "opencode.ai successfully installed!"
    else
      log_error "Failed to install opencode.ai."
    fi
  else
    log_info "Skipped opencode.ai."
  fi
}

# Main Execution Flow
main() {
  print_header
  detect_os

  case "$OS" in
    macos)
      install_macos
    ;;
    ubuntu)
      install_ubuntu
    ;;
    arch)
      install_arch
    ;;
    *)
      log_error "Unsupported operating system."
      log_warning "This script only supports macOS, Ubuntu/Debian, and Arch Linux."
      exit 1
    ;;
  esac
  echo ""

  setup_plugins
  echo ""

  if confirm "Configure Zsh configurations in .zshrc?"; then
    configure_zshrc
  else
    log_info "Skipped .zshrc configuration."
  fi
  echo ""

  if confirm "Change default login shell to Zsh?"; then
    change_shell
  else
    log_info "Skipped default login shell change."
  fi
  echo ""

  setup_dotfiles
  echo ""

  install_opencode

  echo ""
  log_success "Setup complete! Please restart your terminal or run: source ~/.zshrc"
}

main "$@"
