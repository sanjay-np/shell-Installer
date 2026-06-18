# Contributing to Premium Shell Setup & Installer

Thank you for your interest in improving this project! We welcome all contributions, including bug fixes, new features, and documentation enhancements.

---

## 🛠 Guidelines for Modifying `install.sh`

To keep the installation script robust, premium, and cross-platform, please adhere to these core design rules when proposing changes:

### 1. Maintain TUI Column Widths & Layouts
The script implements a premium Terminal User Interface (TUI) based on ANSI escape sequences and exact column calculations:
*   The interactive menus are designed for exactly **70 columns** inside the box.
*   **Do not use double-width characters** (such as certain large icons, wide hexagons, or multi-byte emojis) directly inside box bounds or checkbox indicators. Many terminal fonts render them as 2 columns, which breaks the visual boundaries and wraps/staggers the right borders. Use single-width unicode characters (like `✔`, `▶`, `✘`).
*   Always use the clear-to-end-of-line escape code (`\e[K`) before a newline (`\n`) on dynamically drawn rows to ensure cursor trails are wiped clean.

### 2. Idempotency & Safety
*   **Create backups**: Always run safety backup checks before writing or modifying any configuration files (e.g., `~/.zshrc`, `~/.config/nvim`).
*   **Idempotency blocks**: Zsh configurations must be written inside designated `# >>> installer-setup start >>>` and `# <<< installer-setup end <<<` comment blocks, allowing the installer to update them in place on subsequent runs instead of appending duplicate configurations.

### 3. Bash Conventions
*   Declare helper-scoped variables using `local` inside functions to prevent polluting global scope.
*   Redirect outputs of background commands (like package updates and installs) cleanly to `/dev/null` or our designated log file (`$LOG_FILE`).
*   Always syntax-check the installer before committing:
    ```bash
    bash -n install.sh
    ```

---

## 🚀 How to Contribute

### Reporting Bugs
If you find a visual glitch, an installation failure, or compatibility issues:
1. Check the existing issues list to see if it has already been reported.
2. File a new issue, including your OS version, terminal emulator, font, and a copy of the installer logs (saved at `/tmp/installer_setup.log` or similar).

### Submitting a Pull Request
1. Fork this repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes with descriptive messages.
4. Verify code compiling with `bash -n install.sh`.
5. Open a Pull Request pointing back to the main branch.
