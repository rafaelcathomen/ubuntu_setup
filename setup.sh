#!/usr/bin/env bash
# ubuntu_setup_full.sh
# Purpose: idempotent full setup for Ubuntu 24.04 (safe, robust, verbose)
set -euo pipefail
IFS=$'\n\t'

echo
echo "=== Ubuntu 24.04 Full Setup (idempotent) ==="
echo

# ---------------------------
# Helpers
# ---------------------------
apt_install() {
  # $1..n packages; uses --reinstall to make repeated runs safe
  sudo apt install -y --reinstall "$@"
}

apt_install_no_reinstall() {
  # $1..n packages; avoids --reinstall
  sudo apt install -y "$@"
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------
# 0) System update + prelim
# ---------------------------
echo "-> update & upgrade"
sudo apt update
sudo apt upgrade -y

echo "-> install base tooling"
apt_install_no_reinstall software-properties-common wget curl git build-essential \
  dirmngr gnupg ca-certificates apt-transport-https

# enable multiverse + i386 (needed for Steam & codecs)
sudo add-apt-repository -y multiverse || true
sudo dpkg --add-architecture i386 || true

# ---------------------------
# 1) VSCode repo (official)
# ---------------------------
if [ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]; then
  echo "-> add vscode official repo"
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list
fi

sudo apt update

# ---------------------------
# 2) Core CLI & utils
# ---------------------------
echo "-> install core CLI tools"
apt_install fzf ripgrep bat btop fd-find htop tree tmux unzip zip jq net-tools \
  eza zoxide plocate p7zip-full unrar

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

# ---------------------------
# 3) Python & Miniforge (Mamba)
# ---------------------------
echo "-> install python basics"
apt_install python3 python3-venv python3-pip

if [ ! -d "$HOME/miniforge3" ]; then
  echo "-> installing Miniforge (mambaforge)"
  wget -qO Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
  bash Miniforge3.sh -b -p "$HOME/miniforge3"
  rm Miniforge3.sh
  "$HOME/miniforge3/bin/conda" init zsh || true
fi

# ---------------------------
# 4) Node (nvm)
# ---------------------------
if [ ! -d "$HOME/.nvm" ]; then
  echo "-> install nvm (Node Version Manager) and latest LTS node"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts || true
fi

# ---------------------------
# 5) Dev stack (C/C++, Rust, Docker, Bazel)
# ---------------------------
echo "-> install dev toolchain"
apt_install cmake ninja-build clang clangd clang-format clang-tidy pkg-config gdb \
  build-essential gh openssh-client openssh-server

if ! cmd_exists rustc; then
  echo "-> install rust (rustup)"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
fi

if ! cmd_exists docker; then
  echo "-> install docker (get.docker.com)"
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
fi

if ! cmd_exists bazelisk; then
  echo "-> install bazelisk"
  sudo wget -qO /usr/local/bin/bazelisk https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
  sudo chmod +x /usr/local/bin/bazelisk
  sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel
fi

# ---------------------------
# 6) Shell & terminal
# ---------------------------
echo "-> zsh, alacritty, fonts"
apt_install zsh alacritty fonts-powerline

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "-> install oh-my-zsh (unattended)"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
mkdir -p "$ZSH_CUSTOM"
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ] \
  && git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" || true
[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ] \
  && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" || true

if ! cmd_exists starship; then
  echo "-> install starship prompt"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
fi

grep -q "zoxide init zsh" "$HOME/.zshrc" 2>/dev/null || echo 'eval "$(zoxide init zsh)"' >> "$HOME/.zshrc"
grep -q "direnv hook zsh" "$HOME/.zshrc" 2>/dev/null || echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"

# ---------------------------
# 7) Window manager + GUI utilities (Gammastep removed)
# ---------------------------
echo "-> install i3 + GUI utilities (without gammastep)"
apt_install i3 rofi polybar picom feh dunst lxpolkit network-manager-gnome arandr
apt_install pavucontrol flameshot gnome-tweaks gparted synaptic
apt_install direnv pipx bleachbit || true

# ---------------------------
# 8) Brightness control
# ---------------------------
echo "-> brightness tools (ddcutil + brightnessctl)"
apt_install ddcutil brightnessctl
sudo usermod -aG i2c "$USER" || true

# set-brightness script
sudo tee /usr/local/bin/set-brightness >/dev/null <<'EOF'
#!/usr/bin/env bash
# set-brightness <0-100>  -> set hardware brightness (DDC/CI) on all monitors
if [ $# -ne 1 ]; then
  echo "Usage: set-brightness <0-100>"
  exit 1
fi
LEVEL="$1"
for DISP in $(ddcutil detect 2>/dev/null | awk '/Display/ {print $2}' || true); do
  ddcutil --display "$DISP" setvcp 10 "$LEVEL" || true
done
EOF
sudo chmod +x /usr/local/bin/set-brightness

# set-brightness-fallback script
sudo tee /usr/local/bin/set-brightness-fallback >/dev/null <<'EOF'
#!/usr/bin/env bash
# set-brightness-fallback <percent>
if [ $# -ne 1 ]; then
  echo "Usage: set-brightness-fallback <0-100>"
  exit 1
fi
brightnessctl set "$1"%
EOF
sudo chmod +x /usr/local/bin/set-brightness-fallback

# ---------------------------
# 9) SSH Key Generation (Short Version)
# ---------------------------
SSH_DIR="$HOME/.ssh"
SSH_KEY_FILE="$SSH_DIR/id_ed25519"

# Ensure the directory exists
mkdir -p "$SSH_DIR"

# Generate key if the private key file is missing
if [ ! -f "$SSH_KEY_FILE" ]; then
  echo "-> Generating Ed25519 SSH Key in $SSH_DIR"
  ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -N ''
fi

# ---------------------------
# 10) Apps
# ---------------------------
echo "-> installing applications"
apt_install code steam-installer obs-studio
apt_install flatpak gnome-software-plugin-flatpak

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y --reinstall flathub com.discordapp.Discord || true
flatpak install -y --reinstall flathub com.slack.Slack || true
flatpak install -y --reinstall flathub com.rustdesk.RustDesk || true

# PlotJuggler
if ! cmd_exists plotjuggler; then
  if cmd_exists snap; then
    sudo snap install plotjuggler || true
  else
    sudo apt install -y plotjuggler || true
  fi
fi

# ---------------------------
# 11) Fonts
# ---------------------------
echo "-> install JetBrainsMono Nerd Font locally"
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"
mkdir -p "$FONT_DIR"
if [ ! -f "$FONT_DIR/JetBrainsMono.zip" ]; then
  wget -q -P "$FONT_DIR" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -q "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR" || true
  rm -f "$FONT_DIR/JetBrainsMono.zip"
  fc-cache -fv || true
fi

# ---------------------------
# 12) Firewall & security
# ---------------------------
echo "-> firewall: allow SSH then enable UFW"
sudo ufw allow OpenSSH
sudo ufw --force enable || true

# ---------------------------
# 13) Final notes
# ---------------------------
echo
echo "=== Setup finished ==="
echo "- Reboot or log out/in for group changes (docker, i2c) to take effect."
echo
