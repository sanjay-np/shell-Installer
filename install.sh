#!/usr/bin/env bash

# Cross-Platform Premium Shell Installer TUI
# Configures a premium Zsh environment with Zoxide, Fzf, zsh-autosuggestions, and zsh-syntax-highlighting.
# Supported OSs: macOS, Ubuntu/Debian, Arch Linux.
# Runs in pure Bash using ANSI escape codes and Unicode box-drawing.

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

# Premium TUI theme colors
TUI_TITLE='\033[1;35m'
TUI_SUBTITLE='\033[1;36m'
TUI_BORDER='\033[36m'
TUI_HIGHLIGHT='\033[1;36m'
TUI_CHECKED='\033[1;32m'
TUI_UNCHECKED='\033[90m'
TUI_SUCCESS='\033[1;32m'
TUI_FAILED='\033[1;31m'
TUI_DIM='\033[90m'

# Logging functions (used during installation tasks)
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

# Detect UTF-8 locale for premium Unicode symbol support
detect_unicode() {
  if [[ "$LC_ALL" == *"UTF-8"* || "$LC_CTYPE" == *"UTF-8"* || "$LANG" == *"UTF-8"* ]]; then
    USE_UNICODE=true
  else
    USE_UNICODE=false
  fi
}

detect_unicode

if [ "$USE_UNICODE" = true ]; then
  BOX_TL="┌"
  BOX_TR="┐"
  BOX_BL="└"
  BOX_BR="┘"
  BOX_H="─"
  BOX_V="│"
  BOX_ML="├"
  BOX_MR="┤"
  SYM_CHECKED="✔"
  SYM_UNCHECKED=" "
  SYM_ARROW="▶"
  SYM_SUCCESS="✔"
  SYM_FAILED="✘"
else
  BOX_TL="+"
  BOX_TR="+"
  BOX_BL="+"
  BOX_BR="+"
  BOX_H="-"
  BOX_V="|"
  BOX_ML="+"
  BOX_MR="+"
  SYM_CHECKED="x"
  SYM_UNCHECKED=" "
  SYM_ARROW=">"
  SYM_SUCCESS="OK"
  SYM_FAILED="ERR"
fi

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

# Check terminal size
check_terminal_size() {
  local cols
  local rows
  cols=$(tput cols 2>/dev/null || echo 80)
  rows=$(tput lines 2>/dev/null || echo 24)
  if [ "$cols" -lt 76 ] || [ "$rows" -lt 18 ]; then
    log_warning "Your terminal window is small ($cols x $rows). Premium TUI works best at 76x18 or larger."
    echo -ne "${YELLOW}${BOLD}[PROMPT]${NC} Press Enter to continue anyway... "
    read -r
  fi
}

# TUI Cleanup Trap Function
cleanup_tui() {
  stty echo icanon 2>/dev/null
  printf "\e[?25h" # Show cursor
  if [ -n "$SUDO_PID" ] && kill -0 "$SUDO_PID" 2>/dev/null; then
    kill "$SUDO_PID" 2>/dev/null
  fi
}

tui_exit_handler() {
  clear 2>/dev/null
  cleanup_tui
  echo -e "\n${RED}${BOLD}[ERROR]${NC} Setup cancelled or interrupted."
  exit 1
}
trap tui_exit_handler INT TERM
trap cleanup_tui EXIT

# Setup Sudo credentials before launching the TUI
setup_sudo() {
  if [[ "$OS" == "macos" ]]; then
    log_info "To ensure a smooth setup, the installer may request your password for administrative tasks."
  else
    log_info "This installer requires administrative privileges to install system packages."
  fi
  echo -ne "${YELLOW}${BOLD}[PROMPT]${NC} Press any key to authenticate sudo... "
  read -n 1 -s
  echo ""
  if sudo -v; then
    # Keep-alive: update existing sudo time stamp if set, every 60 seconds
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    SUDO_PID=$!
    log_success "Sudo authenticated successfully!"
    sleep 1
  else
    log_warning "Sudo authentication failed. Steps requiring admin privileges may fail."
    sleep 2
  fi
}

# Check if a package is installed
is_pkg_installed() {
  local pkg="$1"
  local cmd="$pkg"
  
  case "$pkg" in
    neovim)   cmd="nvim" ;;
    ripgrep)  cmd="rg" ;;
    fd)
      if command -v fdfind >/dev/null 2>&1; then return 0; fi
      cmd="fd"
      ;;
    bat)
      if command -v batcat >/dev/null 2>&1; then return 0; fi
      cmd="bat"
      ;;
    ghostty)
      if [[ "$OS" == "macos" ]]; then
        if command -v ghostty >/dev/null 2>&1 || [ -d "/Applications/Ghostty.app" ]; then
          return 0
        fi
      else
        if command -v ghostty >/dev/null 2>&1; then
          return 0
        fi
      fi
      return 1
      ;;
  esac
  
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Packages Configuration
packages=(
  "zsh" "zoxide" "fzf" "git" "curl" "neovim" "tmux" "starship" "ghostty"
  "eza" "bat" "fd" "ripgrep" "btop" "lazygit" "tldr" "gh" "direnv"
  "dust" "fastfetch" "ncdu"
)
package_labels=(
  "Zsh" "Zoxide" "Fzf" "Git" "Curl" "Neovim" "Tmux" "Starship Prompt" "Ghostty Terminal"
  "Eza (ls alternative)" "Bat (cat alternative)" "Fd (find alternative)" "Ripgrep (grep alternative)"
  "Btop system monitor" "Lazygit TUI" "Tldr cheat sheets" "GitHub CLI" "Direnv env switcher"
  "Dust (du alternative)" "Fastfetch system info" "Ncdu disk usage analyzer"
)
package_installed=()
package_selected=()

# Configuration Tweaks
configs=("zshrc" "shell" "plugin_autosuggestions" "plugin_syntax_highlighting" "plugin_fzf_tab" "nvim" "ghostty" "tmux" "starship" "opencode")
config_labels=(
  "Configure Zsh configurations in .zshrc"
  "Change default login shell to Zsh"
  "Install zsh-autosuggestions plugin"
  "Install zsh-syntax-highlighting plugin"
  "Install fzf-tab plugin"
  "Clone dotfiles & configure Neovim"
  "Clone dotfiles & configure Ghostty"
  "Clone dotfiles & configure tmux"
  "Clone dotfiles & configure Starship"
  "Install/upgrade opencode.ai"
)
config_selected=(1 1 0 0 0 0 0 0 0 1)

# Raw Key Reader (POSIX stty-compliant, compatible with Bash 3.2+)
read_key() {
  local key
  local next
  
  # Set terminal to raw blocking mode (wait for at least 1 character)
  stty -echo -icanon min 1 time 0 2>/dev/null
  IFS= read -r -n 1 key
  
  # If escape character, read any immediately following characters from terminal input queue
  if [[ "$key" == $'\e' ]]; then
    # Switch to raw non-blocking mode (return immediately if queue is empty)
    stty -echo -icanon min 0 time 0 2>/dev/null
    IFS= read -r -n 1 next
    if [ -n "$next" ]; then
      key="$key$next"
      IFS= read -r -n 1 next
      if [ -n "$next" ]; then
        key="$key$next"
      fi
    fi
  fi
  
  echo -n "$key"
}

# TUI Drawer Helpers
draw_header() {
  local title="$1"
  local subtitle="$2"
  
  echo ""
  printf "  %b%s%b\e[K\n" "$TUI_TITLE" "$title" "$NC"
  if [ -n "$subtitle" ]; then
    printf "  %b%s%b\e[K\n" "$TUI_SUBTITLE" "$subtitle" "$NC"
  fi
  echo ""
}

draw_footer() {
  printf "%b" "$NC"
}

print_menu_line() {
  local is_cursor=$1 is_selected=$2 label=$3 status=$4
  
  local cursor_sym="  "
  if [ $is_cursor -eq 1 ]; then
    cursor_sym="$SYM_ARROW "
  fi
  
  local chk="$SYM_UNCHECKED"
  if [ $is_selected -eq 1 ]; then
    chk="$SYM_CHECKED"
  fi
  
  local pad_label
  pad_label=$(printf "%-32s" "$label")
  
  local formatted_status=""
  if [ -n "$status" ]; then
    formatted_status="($status)"
  fi
  
  # Print left margin (2 spaces) + cursor symbol
  printf "  "
  if [ $is_cursor -eq 1 ]; then
    printf "%b%s%b " "$TUI_HIGHLIGHT" "$SYM_ARROW" "$NC"
    if [ $is_selected -eq 1 ]; then
      printf "%b[%s]%b %b%s%b %b%s%b" "$TUI_CHECKED" "$chk" "$NC" "$TUI_HIGHLIGHT" "$pad_label" "$NC" "$TUI_CHECKED" "$formatted_status" "$NC"
    else
      printf "%b[%s]%b %b%s%b %b%s%b" "$TUI_UNCHECKED" "$chk" "$NC" "$TUI_HIGHLIGHT" "$pad_label" "$NC" "$TUI_UNCHECKED" "$formatted_status" "$NC"
    fi
  else
    printf "    "
    if [ $is_selected -eq 1 ]; then
      printf "%b[%s]%b %s %s" "$TUI_CHECKED" "$chk" "$NC" "$pad_label" "$formatted_status"
    else
      printf "%b[%s]%b %b%s %s%b" "$TUI_UNCHECKED" "$chk" "$NC" "$TUI_DIM" "$pad_label" "$formatted_status" "$NC"
    fi
  fi
  
  printf "\e[K\n"
}

# Scrollable viewport variables
scroll_offset=0
view_height=8

draw_step1() {
  printf "\e[H"
  draw_header "PREMIUM SHELL SETUP - STEP 1/3" "Select Packages to Install"
  
  printf "  %s\e[K\n" "Use [↑/↓] to navigate, [Space] to toggle, [Enter] to continue."
  echo ""
  
  # Top scroll indicator
  local top_scroll=""
  if [ $scroll_offset -gt 0 ]; then
    top_scroll="▲ More packages above ▲"
  fi
  printf "  %b%s%b\e[K\n" "$TUI_DIM" "$top_scroll" "$NC"
  
  # Print viewport items
  local end_idx=$((scroll_offset + view_height))
  for ((i=scroll_offset; i<end_idx; i++)); do
    local label="${package_labels[i]}"
    local status="Not Installed"
    if [ ${package_installed[i]} -eq 1 ]; then
      status="Installed"
    fi
    
    local is_cursor=0
    if [ $i -eq $cursor ]; then
      is_cursor=1
    fi
    local is_selected=${package_selected[i]}
    
    print_menu_line "$is_cursor" "$is_selected" "$label" "$status"
  done
  
  # Bottom scroll indicator
  local bot_scroll=""
  if [ $((scroll_offset + view_height)) -lt ${#packages[@]} ]; then
    bot_scroll="▼ More packages below ▼"
  fi
  printf "  %b%s%b\e[K\n" "$TUI_DIM" "$bot_scroll" "$NC"
  
  draw_footer
}

run_step1() {
  cursor=0
  scroll_offset=0
  clear
  printf "\e[?25l" # Hide cursor
  stty -echo -icanon 2>/dev/null
  
  while true; do
    draw_step1
    local key
    key=$(read_key)
    case "$key" in
      $'\e[A') # Up arrow
        ((cursor--))
        if [ $cursor -lt 0 ]; then
          cursor=$((${#packages[@]} - 1))
          scroll_offset=$((${#packages[@]} - view_height))
          if [ $scroll_offset -lt 0 ]; then scroll_offset=0; fi
        elif [ $cursor -lt $scroll_offset ]; then
          scroll_offset=$cursor
        fi
        ;;
      $'\e[B') # Down arrow
        ((cursor++))
        if [ $cursor -ge ${#packages[@]} ]; then
          cursor=0
          scroll_offset=0
        elif [ $cursor -ge $((scroll_offset + view_height)) ]; then
          scroll_offset=$((cursor - view_height + 1))
        fi
        ;;
      " ") # Spacebar
        if [ ${package_selected[cursor]} -eq 1 ]; then
          package_selected[cursor]=0
        else
          package_selected[cursor]=1
        fi
        ;;
      ""|$'\n'|$'\r') # Enter
        return 0
        ;;
      $'\e') # Escape (quit in Step 1)
        return 2
        ;;
      "q"|"Q") # Quit
        return 2
        ;;
    esac
  done
}

draw_step2() {
  printf "\e[H"
  draw_header "PREMIUM SHELL SETUP - STEP 2/3" "Select Shell Configurations"
  
  printf "  %s\e[K\n" "Use [↑/↓] to navigate, [Space] to toggle, [Enter] to start install."
  echo ""
  
  for ((i=0; i<${#configs[@]}; i++)); do
    local label="${config_labels[i]}"
    local is_cursor=0
    if [ $i -eq $cursor ]; then
      is_cursor=1
    fi
    local is_selected=${config_selected[i]}
    
    print_menu_line "$is_cursor" "$is_selected" "$label" ""
  done
  
  # Pad to match Step 1 height (10 lines total after header offset)
  local used_lines=${#configs[@]}
  local pad_lines=$(( 10 - used_lines ))
  if [ $pad_lines -lt 0 ]; then pad_lines=0; fi
  for ((p=0; p<pad_lines; p++)); do
    printf "\e[K\n"
  done
  
  draw_footer
}

run_step2() {
  cursor=0
  clear
  printf "\e[?25l" # Hide cursor
  stty -echo -icanon 2>/dev/null
  
  while true; do
    draw_step2
    local key
    key=$(read_key)
    case "$key" in
      $'\e[A') # Up arrow
        ((cursor--))
        if [ $cursor -lt 0 ]; then
          cursor=$((${#configs[@]} - 1))
        fi
        ;;
      $'\e[B') # Down arrow
        ((cursor++))
        if [ $cursor -ge ${#configs[@]} ]; then
          cursor=0
        fi
        ;;
      " ") # Spacebar
        if [ ${config_selected[cursor]} -eq 1 ]; then
          config_selected[cursor]=0
        else
          config_selected[cursor]=1
        fi
        ;;
      ""|$'\n'|$'\r') # Enter
        return 0
        ;;
      $'\e') # Escape (previous step in Step 2)
        return 1
        ;;
      "q"|"Q") # Quit
        return 2
        ;;
    esac
  done
}

# Non-interactive installation routines

run_install_macos() {
  log_info "Running macOS installation tasks..."
  
  # Install Homebrew if missing
  if ! command -v brew >/dev/null 2>&1; then
    log_info "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
    
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  
  export HOMEBREW_NO_AUTO_UPDATE=1
  
  for ((i=0; i<${#packages[@]}; i++)); do
    local pkg="${packages[i]}"
    if [ "${package_selected[i]}" -eq 1 ] && [ "$pkg" != "ghostty" ]; then
      log_info "Installing/upgrading package '$pkg'..."
      brew install "$pkg" </dev/null
    fi
  done
  
  # Install Ghostty Cask if selected
  local ghostty_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "ghostty" ]; then ghostty_idx=$i; break; fi
  done
  if [ $ghostty_idx -ne -1 ] && [ "${package_selected[ghostty_idx]}" -eq 1 ]; then
    log_info "Installing Ghostty Cask..."
    brew install --cask ghostty </dev/null
  fi
}

run_install_ubuntu() {
  log_info "Updating Ubuntu package lists..."
  sudo apt-get update -y </dev/null

  for ((i=0; i<${#packages[@]}; i++)); do
    local pkg="${packages[i]}"
    if [ "${package_selected[i]}" -eq 1 ]; then
      if [[ "$pkg" != "zoxide" && "$pkg" != "starship" && "$pkg" != "ghostty" && "$pkg" != "eza" && "$pkg" != "lazygit" && "$pkg" != "dust" && "$pkg" != "fastfetch" ]]; then
        local apt_pkg="$pkg"
        if [ "$pkg" = "fd" ]; then
          apt_pkg="fd-find"
        fi
        log_info "Installing/upgrading package '$apt_pkg'..."
        sudo apt-get install -y "$apt_pkg" </dev/null
      fi
    fi
  done

  # Custom check for Eza
  local eza_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "eza" ]; then eza_idx=$i; break; fi
  done
  if [ $eza_idx -ne -1 ] && [ "${package_selected[eza_idx]}" -eq 1 ]; then
    if apt-cache show eza >/dev/null 2>&1; then
      log_info "Installing eza via apt-get..."
      sudo apt-get install -y eza </dev/null
    elif apt-cache show exa >/dev/null 2>&1; then
      log_info "eza not found in apt. Installing exa (ls replacement) instead..."
      sudo apt-get install -y exa </dev/null
    else
      log_info "eza not found in apt. Installing via snap..."
      sudo snap install eza </dev/null
    fi
  fi

  # Custom check for Lazygit
  local lazygit_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "lazygit" ]; then lazygit_idx=$i; break; fi
  done
  if [ $lazygit_idx -ne -1 ] && [ "${package_selected[lazygit_idx]}" -eq 1 ]; then
    if apt-cache show lazygit >/dev/null 2>&1; then
      log_info "Installing lazygit via apt-get..."
      sudo apt-get install -y lazygit </dev/null
    else
      log_info "lazygit not found in apt. Installing via snap..."
      sudo snap install lazygit --classic </dev/null
    fi
  fi

  # Custom check for Zoxide
  local zoxide_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "zoxide" ]; then zoxide_idx=$i; break; fi
  done
  if [ $zoxide_idx -ne -1 ] && [ "${package_selected[zoxide_idx]}" -eq 1 ]; then
    if apt-cache show zoxide >/dev/null 2>&1; then
      log_info "Installing zoxide via apt-get..."
      sudo apt-get install -y zoxide </dev/null
    else
      log_warning "zoxide not found in apt. Installing via script..."
      curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh </dev/null
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi

  # Custom check for Starship
  local starship_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "starship" ]; then starship_idx=$i; break; fi
  done
  if [ $starship_idx -ne -1 ] && [ "${package_selected[starship_idx]}" -eq 1 ]; then
    log_info "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes </dev/null
  fi

  # Custom check for Ghostty
  local ghostty_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "ghostty" ]; then ghostty_idx=$i; break; fi
  done
  if [ $ghostty_idx -ne -1 ] && [ "${package_selected[ghostty_idx]}" -eq 1 ]; then
    if command -v snap >/dev/null 2>&1; then
      log_info "Installing Ghostty via snap..."
      sudo snap install ghostty </dev/null
    elif apt-cache show ghostty >/dev/null 2>&1; then
      log_info "Installing Ghostty via apt..."
      sudo apt-get install -y ghostty </dev/null
    else
      log_warning "Ghostty terminal is not available in snap or apt repositories."
    fi
  fi

  # Custom check for Dust
  local dust_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "dust" ]; then dust_idx=$i; break; fi
  done
  if [ $dust_idx -ne -1 ] && [ "${package_selected[dust_idx]}" -eq 1 ]; then
    if apt-cache show du-dust >/dev/null 2>&1; then
      log_info "Installing dust via apt-get..."
      sudo apt-get install -y du-dust </dev/null
    elif command -v snap >/dev/null 2>&1; then
      log_info "Installing dust via snap..."
      sudo snap install dust </dev/null
    else
      log_warning "Dust is not available in apt or snap repositories."
    fi
  fi

  # Custom check for Fastfetch
  local fastfetch_idx=-1
  for ((i=0; i<${#packages[@]}; i++)); do
    if [ "${packages[i]}" = "fastfetch" ]; then fastfetch_idx=$i; break; fi
  done
  if [ $fastfetch_idx -ne -1 ] && [ "${package_selected[fastfetch_idx]}" -eq 1 ]; then
    if apt-cache show fastfetch >/dev/null 2>&1; then
      log_info "Installing fastfetch via apt-get..."
      sudo apt-get install -y fastfetch </dev/null
    elif command -v snap >/dev/null 2>&1; then
      log_info "Installing fastfetch via snap..."
      sudo snap install fastfetch </dev/null
    else
      log_warning "Fastfetch is not available in apt or snap repositories."
    fi
  fi
}

run_install_arch() {
  log_info "Running Arch Linux installation tasks..."
  for ((i=0; i<${#packages[@]}; i++)); do
    local pkg="${packages[i]}"
    if [ "${package_selected[i]}" -eq 1 ]; then
      local pacman_pkg="$pkg"
      if [ "$pkg" = "gh" ]; then
        pacman_pkg="github-cli"
      fi
      log_info "Installing/upgrading package '$pacman_pkg'..."
      sudo pacman -Sy --needed --noconfirm "$pacman_pkg" </dev/null
    fi
  done
}

run_setup_plugins() {
  local plugin_dir="$HOME/.zsh/plugins"
  
  local chosen_plugins=()
  if [ ${config_selected[2]} -eq 1 ]; then chosen_plugins+=("zsh-autosuggestions"); fi
  if [ ${config_selected[3]} -eq 1 ]; then chosen_plugins+=("zsh-syntax-highlighting"); fi
  if [ ${config_selected[4]} -eq 1 ]; then chosen_plugins+=("fzf-tab"); fi
  
  if [ ${#chosen_plugins[@]} -eq 0 ]; then
    return 0
  fi
  
  local joined_plugins=""
  for item in "${chosen_plugins[@]}"; do
    if [ -z "$joined_plugins" ]; then
      joined_plugins="$item"
    else
      joined_plugins="${joined_plugins}/${item}"
    fi
  done
  
  log_info "Setting up $joined_plugins Zsh plugins in $plugin_dir..."
  mkdir -p "$plugin_dir"

  # zsh-autosuggestions
  if [ ${config_selected[2]} -eq 1 ]; then
    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
      log_info "Cloning zsh-autosuggestions..."
      git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
    else
      log_info "zsh-autosuggestions exists. Pulling latest updates..."
      git -C "$plugin_dir/zsh-autosuggestions" pull
    fi
  fi

  # zsh-syntax-highlighting
  if [ ${config_selected[3]} -eq 1 ]; then
    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then
      log_info "Cloning zsh-syntax-highlighting..."
      git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_dir/zsh-syntax-highlighting"
    else
      log_info "zsh-syntax-highlighting exists. Pulling latest updates..."
      git -C "$plugin_dir/zsh-syntax-highlighting" pull
    fi
  fi

  # fzf-tab
  if [ ${config_selected[4]} -eq 1 ]; then
    if [ ! -d "$plugin_dir/fzf-tab" ]; then
      log_info "Cloning fzf-tab..."
      git clone https://github.com/Aloxaf/fzf-tab "$plugin_dir/fzf-tab"
    else
      log_info "fzf-tab exists. Pulling latest updates..."
      git -C "$plugin_dir/fzf-tab" pull
    fi
  fi
}

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
  # ---- Zoxide (better cd) ----
  eval "$(zoxide init zsh)"
  alias cd="z"
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

# Setup Direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Setup Eza Aliases
if command -v eza >/dev/null 2>&1; then
  # ---- Eza (better ls) -----
  alias ls="eza --color=always --long --git --no-filesize --icons=always --no-time --no-user --no-permissions --tree --level=1"
fi
# <<< installer-setup end <<<
EOF
  )

  # Check if block is already present in .zshrc
  if grep -q "# >>> installer-setup start >>>" "$zshrc"; then
    log_info "Updating existing configuration block in .zshrc..."
    local temp_file
    temp_file=$(mktemp)

    awk '/# >>> installer-setup start >>>/{flag=1;next}/# <<< installer-setup end <<</{flag=0;next}!flag' "$zshrc" > "$temp_file"
    echo "$config_block" >> "$temp_file"
    mv "$temp_file" "$zshrc"
  else
    log_info "Appending configuration block to .zshrc..."
    [ -s "$zshrc" ] && [ -n "$(tail -c1 "$zshrc" 2>/dev/null)" ] && echo "" >> "$zshrc"
    echo "$config_block" >> "$zshrc"
  fi

  log_success ".zshrc successfully configured!"
}

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
    log_info "Current default login shell: $current_shell"
    log_info "Changing default login shell to Zsh ($target_shell)..."
    if sudo chsh -s "$target_shell" "$USER"; then
      log_success "Default login shell changed to Zsh successfully!"
    else
      log_error "Could not automatically change default login shell."
      return 1
    fi
  else
    log_success "Zsh ($current_shell) is already default login shell."
  fi
}

run_setup_dotfiles() {
  local config_dir="$HOME/.config"
  mkdir -p "$config_dir"

  local chosen_dots=()
  if [ ${config_selected[5]} -eq 1 ]; then chosen_dots+=("Neovim"); fi
  if [ ${config_selected[6]} -eq 1 ]; then chosen_dots+=("Ghostty"); fi
  if [ ${config_selected[7]} -eq 1 ]; then chosen_dots+=("tmux"); fi
  if [ ${config_selected[8]} -eq 1 ]; then chosen_dots+=("Starship"); fi

  local joined_dots=""
  for item in "${chosen_dots[@]}"; do
    if [ -z "$joined_dots" ]; then
      joined_dots="$item"
    else
      joined_dots="${joined_dots}/${item}"
    fi
  done

  log_info "Setting up $joined_dots configurations from dotfiles repository..."
  local temp_dir
  temp_dir=$(mktemp -d)

  log_info "Cloning dotfiles repository..."
  if git clone https://github.com/sanjay-np/dotfiles "$temp_dir" >/dev/null 2>&1; then
    
    # Setup Neovim Config
    if [ ${config_selected[5]} -eq 1 ]; then
      if [ -d "$temp_dir/nvim" ]; then
        if [ -e "$config_dir/nvim" ]; then
          local nvim_backup="${config_dir}/nvim.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing Neovim configuration found. Backing up to $nvim_backup..."
          mv "$config_dir/nvim" "$nvim_backup"
        fi
        log_info "Copying Neovim configuration to $config_dir/nvim..."
        cp -R "$temp_dir/nvim" "$config_dir/nvim"
        log_success "Neovim configuration successfully set up!"
      else
        log_warning "No 'nvim' directory found in dotfiles repository."
      fi
    fi

    # Setup Ghostty Config
    if [ ${config_selected[6]} -eq 1 ]; then
      if [ -d "$temp_dir/ghostty" ]; then
        if [ -e "$config_dir/ghostty" ]; then
          local ghostty_backup="${config_dir}/ghostty.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing Ghostty configuration found. Backing up to $ghostty_backup..."
          mv "$config_dir/ghostty" "$ghostty_backup"
        fi
        log_info "Copying Ghostty configuration to $config_dir/ghostty..."
        cp -R "$temp_dir/ghostty" "$config_dir/ghostty"
        log_success "Ghostty configuration successfully set up!"
      else
        log_warning "No 'ghostty' directory found in dotfiles repository."
      fi
    fi

    # Setup tmux Config
    if [ ${config_selected[7]} -eq 1 ]; then
      if [ -d "$temp_dir/tmux" ]; then
        if [ -e "$config_dir/tmux" ]; then
          local tmux_backup="${config_dir}/tmux.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing tmux configuration found. Backing up to $tmux_backup..."
          mv "$config_dir/tmux" "$tmux_backup"
        fi
        log_info "Copying tmux configuration to $config_dir/tmux..."
        cp -R "$temp_dir/tmux" "$config_dir/tmux"
        log_success "tmux configuration successfully set up!"
      else
        log_warning "No 'tmux' directory found in dotfiles repository."
      fi
    fi

    # Setup Starship Config
    if [ ${config_selected[8]} -eq 1 ]; then
      if [ -f "$temp_dir/starship.toml" ]; then
        if [ -e "$config_dir/starship.toml" ]; then
          local starship_backup="${config_dir}/starship.toml.bak_$(date +%Y%m%d_%H%M%S)"
          log_info "Existing Starship configuration found. Backing up to $starship_backup..."
          mv "$config_dir/starship.toml" "$starship_backup"
        fi
        log_info "Copying Starship configuration to $config_dir/starship.toml..."
        cp "$temp_dir/starship.toml" "$config_dir/starship.toml"
        log_success "Starship configuration successfully set up!"
      else
        log_warning "No 'starship.toml' file found in dotfiles repository."
      fi
    fi

    rm -rf "$temp_dir"
  else
    log_error "Failed to clone dotfiles repository. Skipping config setups."
    rm -rf "$temp_dir"
    return 1
  fi
}

run_install_opencode() {
  log_info "Installing opencode.ai via official curl script..."
  if curl -fsSL https://opencode.ai/install | bash; then
    log_success "opencode.ai successfully installed!"
  else
    log_error "Failed to install opencode.ai."
    return 1
  fi
}

run_current_task() {
  local task="$1"
  case "$task" in
    packages)
      case "$OS" in
        macos) run_install_macos ;;
        ubuntu) run_install_ubuntu ;;
        arch) run_install_arch ;;
      esac
      ;;
    plugins)
      run_setup_plugins
      ;;
    zshrc)
      configure_zshrc
      ;;
    shell)
      change_shell
      ;;
    dotfiles)
      run_setup_dotfiles
      ;;
    opencode)
      run_install_opencode
      ;;
  esac
}

# Step 3 Task Builder & Runner
run_tasks=()
run_task_labels=()
run_task_status=() # 0: Pending, 1: Running, 2: Success, 3: Failed, 4: Skipped

build_run_tasks() {
  local any_pkg_selected=0
  for s in "${package_selected[@]}"; do
    if [ "$s" -eq 1 ]; then
      any_pkg_selected=1
    fi
  done
  
  local task_idx=0
  
  # 1. Packages Task
  run_tasks[task_idx]="packages"
  run_task_labels[task_idx]="Installing selected packages"
  if [ $any_pkg_selected -eq 1 ]; then
    run_task_status[task_idx]=0
  else
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
  
  # 2. Plugins Task
  run_tasks[task_idx]="plugins"
  local selected_plugins=()
  if [ ${config_selected[2]} -eq 1 ]; then selected_plugins+=("autosuggestions"); fi
  if [ ${config_selected[3]} -eq 1 ]; then selected_plugins+=("syntax-highlighting"); fi
  if [ ${config_selected[4]} -eq 1 ]; then selected_plugins+=("fzf-tab"); fi
  
  if [ ${#selected_plugins[@]} -gt 0 ]; then
    local joined_plugins=""
    for item in "${selected_plugins[@]}"; do
      if [ -z "$joined_plugins" ]; then
        joined_plugins="$item"
      else
        joined_plugins="${joined_plugins}, ${item}"
      fi
    done
    run_task_labels[task_idx]="Setting up Zsh plugins: $joined_plugins"
    run_task_status[task_idx]=0
  else
    run_task_labels[task_idx]="Setting up custom Zsh plugins"
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
  
  # 3. Zshrc Settings Task
  run_tasks[task_idx]="zshrc"
  run_task_labels[task_idx]="Configuring .zshrc settings"
  if [ ${config_selected[0]} -eq 1 ]; then
    run_task_status[task_idx]=0
  else
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
  
  # 4. Default Shell Task
  run_tasks[task_idx]="shell"
  run_task_labels[task_idx]="Changing default login shell to Zsh"
  if [ ${config_selected[1]} -eq 1 ]; then
    run_task_status[task_idx]=0
  else
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
  
  # 5. Dotfiles Task
  run_tasks[task_idx]="dotfiles"
  local selected_dots=()
  if [ ${config_selected[5]} -eq 1 ]; then selected_dots+=("Neovim"); fi
  if [ ${config_selected[6]} -eq 1 ]; then selected_dots+=("Ghostty"); fi
  if [ ${config_selected[7]} -eq 1 ]; then selected_dots+=("tmux"); fi
  if [ ${config_selected[8]} -eq 1 ]; then selected_dots+=("Starship"); fi
  
  if [ ${#selected_dots[@]} -gt 0 ]; then
    local joined_dots=""
    for item in "${selected_dots[@]}"; do
      if [ -z "$joined_dots" ]; then
        joined_dots="$item"
      else
        joined_dots="${joined_dots}, ${item}"
      fi
    done
    run_task_labels[task_idx]="Cloning dotfiles & configuring $joined_dots"
    run_task_status[task_idx]=0
  else
    run_task_labels[task_idx]="Cloning dotfiles & configuring applications"
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
  
  # 6. Opencode Task
  run_tasks[task_idx]="opencode"
  run_task_labels[task_idx]="Installing/upgrading opencode.ai"
  if [ ${config_selected[9]} -eq 1 ]; then
    run_task_status[task_idx]=0
  else
    run_task_status[task_idx]=4
  fi
  ((task_idx++))
}

draw_step3() {
  local spinner="$1"
  printf "\e[H"
  
  draw_header "PREMIUM SHELL SETUP - STEP 3/3" "Executing Installations..."
  
  for ((i=0; i<${#run_tasks[@]}; i++)); do
    local label="${run_task_labels[i]}"
    local status="${run_task_status[i]}"
    local sym="$SYM_UNCHECKED"
    local color=""
    
    case "$status" in
      0) # Pending
        sym="$SYM_UNCHECKED"
        color="$TUI_DIM"
        ;;
      1) # Running
        sym="$spinner"
        color="$TUI_HIGHLIGHT"
        ;;
      2) # Success
        sym="$SYM_SUCCESS"
        color="$TUI_SUCCESS"
        ;;
      3) # Failed
        sym="$SYM_FAILED"
        color="$TUI_FAILED"
        ;;
      4) # Skipped
        sym="$SYM_UNCHECKED"
        color="$TUI_DIM"
        label="$label (Skipped)"
        ;;
    esac
    
    printf "  %b[%s]%b %b%s%b\e[K\n" "$color" "$sym" "$NC" "$color" "$label"
  done
  
  # Pad tasks box to height 7 if there are fewer
  local pad_t=$(( 7 - ${#run_tasks[@]} ))
  if [ $pad_t -lt 0 ]; then pad_t=0; fi
  for ((i=0; i<pad_t; i++)); do
    printf "\e[K\n"
  done
  
  echo ""
  
  # Log title
  printf "  \033[1;33mLIVE INSTALLATION LOGS (tail)\033[0m\e[K\n"
  echo ""
  
  # Draw log lines
  local count=0
  if [ -f "$LOG_FILE" ]; then
    local line
    while IFS= read -r line || [ -n "$line" ]; do
      # Remove carriage returns and extract last status on the line, strip ANSI, replace tabs
      local plain_line
      plain_line=$(echo "$line" | tr '\r' '\n' | tail -n 1 | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | tr '\t' ' ')
      
      if [ ${#plain_line} -gt 70 ]; then
        plain_line="${plain_line:0:67}..."
      fi
      
      printf "    %b%s%b\e[K\n" "$TUI_DIM" "$plain_line" "$NC"
      ((count++))
      if [ $count -eq 6 ]; then break; fi
    done < <(tail -n 6 "$LOG_FILE" 2>/dev/null)
  fi
  
  # Fill remaining log lines
  for ((i=count; i<6; i++)); do
    printf "\e[K\n"
  done
  
  draw_footer
}

run_step3() {
  clear
  printf "\e[?25l" # Hide cursor
  
  # Setup log file
  LOG_FILE=$(mktemp -t installer_setup.log 2>/dev/null || echo "/tmp/installer_setup.log")
  echo "--- Premium Installer Setup Log Started ---" > "$LOG_FILE"
  echo "OS Detected: $OS" >> "$LOG_FILE"
  echo "Date: $(date)" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
  
  local spinner_frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  
  for ((t=0; t<${#run_tasks[@]}; t++)); do
    local task_name="${run_tasks[t]}"
    local task_state="${run_task_status[t]}"
    
    if [ "$task_state" -eq 0 ]; then
      run_task_status[t]=1 # Running
      
      # Start in background
      run_current_task "$task_name" >> "$LOG_FILE" 2>&1 &
      local task_pid=$!
      
      local frame_idx=0
      while kill -0 $task_pid 2>/dev/null; do
        draw_step3 "${spinner_frames[frame_idx]}"
        frame_idx=$(( (frame_idx + 1) % 10 ))
        sleep 0.1
      done
      
      wait $task_pid
      local exit_code=$?
      if [ $exit_code -eq 0 ]; then
        run_task_status[t]=2 # Success
      else
        run_task_status[t]=3 # Failed
      fi
    fi
    
    draw_step3 " "
  done
  
  sleep 1
  clear
  cleanup_tui
  
  # Print beautiful final summary
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo -e "${GREEN}${BOLD}             INSTALLATION COMPLETE!               ${NC}"
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo ""
  
  local failures=0
  for ((t=0; t<${#run_tasks[@]}; t++)); do
    local label="${run_task_labels[t]}"
    local status="${run_task_status[t]}"
    if [ "$status" -eq 2 ]; then
      echo -e "${GREEN}${BOLD}[✔]${NC} $label"
    elif [ "$status" -eq 3 ]; then
      echo -e "${RED}${BOLD}[✘]${NC} $label (Failed)"
      ((failures++))
    elif [ "$status" -eq 4 ]; then
      echo -e "${YELLOW}[-]${NC} $label (Skipped)"
    fi
  done
  
  echo ""
  if [ $failures -gt 0 ]; then
    log_warning "Installation finished with $failures errors. Please review the log file at:"
    echo -e "  ${BOLD}$LOG_FILE${NC}"
  else
    log_success "All tasks completed successfully!"
    log_info "Detailed setup logs are saved at: $LOG_FILE"
  fi
  echo ""
  log_success "Setup complete! Please restart your terminal or run: source ~/.zshrc"
  echo ""
}

# Print beautiful header for non-TUI parts
print_header() {
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo -e "${CYAN}${BOLD}       PREMIUM SHELL SETUP & INSTALLER            ${NC}"
  echo -e "${MAGENTA}${BOLD}==================================================${NC}"
  echo ""
}

main() {
  print_header
  detect_os
  
  if [ "$OS" = "unknown" ]; then
    log_error "Unsupported operating system."
    log_warning "This script only supports macOS, Ubuntu/Debian, and Arch Linux."
    exit 1
  fi
  
  check_terminal_size
  
  # Authenticate sudo first so TUI background calls aren't blocked
  setup_sudo
  
  log_info "Scanning current package statuses..."
  for ((i=0; i<${#packages[@]}; i++)); do
    if is_pkg_installed "${packages[i]}"; then
      package_installed[i]=1
      package_selected[i]=0 # Do not pre-select if already installed
    else
      package_installed[i]=0
      package_selected[i]=1 # Pre-select by default if not installed
    fi
  done
  
  # Run TUI Setup Wizard state machine
  local wizard_step=1
  while true; do
    case "$wizard_step" in
      1)
        run_step1
        local ret_step1=$?
        if [ $ret_step1 -eq 0 ]; then
          wizard_step=2
        elif [ $ret_step1 -eq 2 ]; then
          clear
          cleanup_tui
          log_info "Setup cancelled by user."
          exit 0
        fi
        ;;
      2)
        run_step2
        local ret_step2=$?
        if [ $ret_step2 -eq 0 ]; then
          wizard_step=3
          break
        elif [ $ret_step2 -eq 1 ]; then
          wizard_step=1
        elif [ $ret_step2 -eq 2 ]; then
          clear
          cleanup_tui
          log_info "Setup cancelled by user."
          exit 0
        fi
        ;;
    esac
  done
  
  # Build Step 3 status tasks
  build_run_tasks
  
  # Run installations
  run_step3
}

main "$@"
