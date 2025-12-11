#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Ubuntu 24.04 "Noble Numbat" Setup Script
# ==========================================

echo "Starting setup... NOTE: Run this as your user, NOT root."
echo "You will be asked for your sudo password shortly."

# -------------------------------
# 0️⃣  Prep & Repositories
# -------------------------------
# Enable multiverse (needed for Steam/drivers)
sudo add-apt-repository multiverse -y
sudo dpkg --add-architecture i386

# Update & upgrade
sudo apt update && sudo apt upgrade -y

# Install essential basics first
sudo apt install -y curl git wget software-properties-common build-essential

# -------------------------------
# 1️⃣  Core CLI & Modern Unix Tools
# -------------------------------
# fastfetch > neofetch
# eza > ls
# zoxide > cd
sudo apt install -y \
    fzf ripgrep bat btop fd-find htop tree tmux \
    unzip zip jq net-tools fastfetch eza zoxide plocate \
    p7zip-full unrar

# Fix bat and fd naming conflicts (Ubuntu specifics)
[ ! -f ~/.local/bin/bat ] && mkdir -p ~/.local/bin && ln -s /usr/bin/batcat ~/.local/bin/bat || true
[ ! -f ~/.local/bin/fd ] && ln -s /usr/bin/fdfind ~/.local/bin/fd || true

# -------------------------------
# 2️⃣  Development Stacks
# -------------------------------

# --- Python (Miniforge3) ---
sudo apt install -y python3 python3-venv python3-pip
if [ ! -d "$HOME/miniforge3" ]; then
    echo "Installing Miniforge3 (Conda/Mamba)..."
    wget -qO Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
    bash Miniforge3.sh -b -p "$HOME/miniforge3"
    rm Miniforge3.sh
    # Init for zsh (will be applied later when zsh is set up)
    eval "$($HOME/miniforge3/bin/conda shell.zsh hook)"
    conda init zsh
fi

# --- Node.js (via NVM) ---
# Even for non-JS devs, NVM is useful for tools that depend on Node
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
fi

# --- C++ / Build Tools ---
sudo apt install -y \
    cmake ninja-build clang clangd clang-format clang-tidy pkg-config gdb

# --- Rust ---
if ! command -v rustc &>/dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# --- Bazel (via Bazelisk) ---
if ! command -v bazelisk &>/dev/null; then
    echo "Installing Bazelisk..."
    sudo wget -qO /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
    sudo chmod +x /usr/local/bin/bazelisk
    # Alias bazel -> bazelisk
    if [ ! -f /usr/local/bin/bazel ]; then
        sudo ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel
    fi
fi

# -------------------------------
# 3️⃣  Shell & Terminal
# -------------------------------
sudo apt install -y zsh alacritty

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM}/plugins/zsh-autosuggestions || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting || true

# Starship prompt
if ! command -v starship &>/dev/null; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

# -------------------------------
# 4️⃣  Window Manager (i3) & GUI Utils
# -------------------------------
# i3, Rofi, Polybar, Picom (Compositor), Feh (Wallpaper), Dunst (Notifications)
# Lxpolkit (Authentication Agent - REQUIRED for GUI apps needing sudo)
# Arandr (Screen Layout GUI), Network Manager Applet
sudo apt install -y \
    i3 rofi polybar picom feh dunst \
    lxpolkit network-manager-gnome arandr \
    pavucontrol brightnessctl ddcutil

# -------------------------------
# 5️⃣  GUI Applications
# -------------------------------

# --- VS Code (Microsoft Repo) ---
if ! command -v code &>/dev/null; then
    echo "Installing VS Code..."
    sudo apt-get install -y apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm packages.microsoft.gpg
    sudo apt update
    sudo apt install -y code
fi

# --- Chrome (Direct .deb) ---
if ! command -v google-chrome-stable &>/dev/null; then
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    rm google-chrome-stable_current_amd64.deb
fi

# --- Docker (Official Script) ---
if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
fi
sudo apt install -y docker-compose-plugin

# --- Flatpak & Apps ---
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.discordapp.Discord
flatpak install -y flathub com.slack.Slack

# --- Other Apps ---
sudo apt install -y \
    steam-installer obs-studio \
    gnome-tweaks gparted synaptic flameshot gammastep \
    direnv pipx bleachbit ufw \
    ubuntu-restricted-extras

# --- PlotJuggler (Snap) ---
# Snap comes pre-installed on Ubuntu 24.04
sudo snap install plotjuggler

# -------------------------------
# 6️⃣  Fonts (Nerd Fonts)
# -------------------------------
# Installing JetBrains Mono Nerd Font for Starship/Terminal icons
FONT_DIR="$HOME/.local/share/fonts"
if [ ! -d "$FONT_DIR/JetBrainsMono" ]; then
    echo "Installing JetBrains Mono Nerd Font..."
    mkdir -p "$FONT_DIR/JetBrainsMono"
    wget -P "$FONT_DIR/JetBrainsMono" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip "$FONT_DIR/JetBrainsMono/JetBrainsMono.zip" -d "$FONT_DIR/JetBrainsMono"
    rm "$FONT_DIR/JetBrainsMono/JetBrainsMono.zip"
    fc-cache -fv
fi

# -------------------------------
# 7️⃣  Final Configuration
# -------------------------------

# Enable Firewall
sudo ufw enable

# Add zoxide and direnv to .zshrc if not present
if ! grep -q "zoxide init zsh" "$HOME/.zshrc"; then
    echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
fi
if ! grep -q "direnv hook zsh" "$HOME/.zshrc"; then
    echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"
fi

echo "=============================================="
echo "✅ Ubuntu 24.04 setup script completed!"
echo "----------------------------------------------"
echo "👉 Reboot recommended."
echo "👉 Log in via 'i3' session (click the gear icon)."
echo "👉 Configure 'gh auth login' manually."
echo "👉 If VS Code fonts look weird, select 'JetBrainsMono NF' in settings."
echo "=============================================="
