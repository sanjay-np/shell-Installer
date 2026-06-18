# Premium Cross-Platform Shell Setup & Installer

An elegant, robust, and completely idempotent Bash script (`install.sh`) to bootstrap a premium shell environment on **macOS**, **Ubuntu/Debian**, and **Arch Linux**.

---

## 🚀 Features

*   **Intelligent OS Detection**: Automatically adapts commands for macOS (Homebrew Cask/Formulas), Ubuntu (Apt-get / Snaps), and Arch Linux (Pacman).
*   **Idempotent Installation**: Automatically checks if a package is already installed before calling the package manager, avoiding redundant installation steps and noisy warning messages.
*   **Zsh Completion & Highlight Custom Plugins**: Clones and manages plugins directly from GitHub to a consistent location (`~/.zsh/plugins/`) so they work identically across all your machines:
    *   [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
    *   [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
    *   [fzf-tab](https://github.com/Aloxaf/fzf-tab)
*   **Starship Integration**: Automatically installs [Starship](https://starship.rs/) and initializes it cleanly inside your `.zshrc`.
*   **Modern CLI Stack**: Installs `neovim`, `tmux`, `zoxide`, `fzf`, `git`, `curl`, and `ghostty` terminal.
*   **Automated Dotfiles Configuration**: Safely clones custom configurations from a personal dotfiles repository (`https://github.com/sanjay-np/dotfiles`) and syncs Neovim and Ghostty configurations directly to your `~/.config/` directory.
*   **Automatic Backup Safeguards**: Before altering `.zshrc`, `~/.config/nvim`, or `~/.config/ghostty`, the script automatically creates timestamped backups (e.g., `~/.zshrc.bak_YYYYMMDD_HHMMSS`), ensuring zero data loss.
*   **Smart Shell Switching**: Automatically triggers `chsh` to switch your default login shell to Zsh, dynamically bypassing password prompts if you are already using Zsh.
*   **Premium CLI Presentation**: Features color-coded logging statuses (`[INFO]`, `[SUCCESS]`, `[WARNING]`, `[ERROR]`) with visual gaps between logical execution groups.

---

## 📦 Installed Package Stack

| Tool | Purpose | macOS | Ubuntu/Debian | Arch Linux |
| :--- | :--- | :--- | :--- | :--- |
| **Zsh** | Shell | Homebrew | Apt | Pacman |
| **Zoxide** | Smart directories (`z`) | Homebrew | Apt / Installer | Pacman |
| **Fzf** | Fuzzy Finder | Homebrew | Apt | Pacman |
| **Starship** | Premium Prompt | Homebrew | Script | Pacman |
| **Neovim** | Editor | Homebrew | Apt | Pacman |
| **Tmux** | Terminal multiplexer | Homebrew | Apt | Pacman |
| **Ghostty** | GPU terminal | Homebrew Cask | Snap / Apt | Pacman |
| **OpenCode.ai** | AI integration | Curl | Curl | Curl |

---

## 🛠 Usage Instructions

### 1. Make the script executable:
```bash
chmod +x install.sh
```

### 2. Run the installer script:
```bash
./install.sh
```

### 3. Reload your shell configuration:
```bash
source ~/.zshrc
```

---

## 🔒 Configuration Safeguard Block

The installer appends and updates your `~/.zshrc` inside a designated block. Running the script multiple times will update this block in-place instead of creating duplicates:

```bash
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
```
