#!/bin/bash

set -euo pipefail

clear

# -------------------------------#
# SETUP VARIABLES #
# -------------------------------#

readonly PYTHON_VERSION="3"
readonly ZSHRC_FILE="$HOME/.zshrc"
readonly GIT_SSH_KEY_NAME="git"

LOG_FILE="/tmp/devenv_setup_$(date +%Y%m%d_%H%M%S).log"
readonly LOG_FILE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# -------------------------------#
# HELPER FUNCTIONS #
# -------------------------------#

log() {
  echo -e "$1" | tee -a "$LOG_FILE"
}

error() {
  log "${RED}ERROR: $1${NC}"
  exit 1
}

success() {
  log "${GREEN}$1${NC}"
}

info() {
  log "${BLUE}$1${NC}"
}

warning() {
  log "${YELLOW}$1${NC}"
}

progress() {
  log "${CYAN}$1${NC}"
}

check_command() {
  command -v "$1" &>/dev/null
}

# shellcheck disable=SC2024
sudo_log() {
  sudo "$@" >> "$LOG_FILE" 2>&1
}

install_package() {
  local package="$1"
  progress "Installing $package..."
  if sudo_log apt install -y "$package"; then
    success "$package installed"
  else
    error "Failed to install $package"
  fi
}

clone_zsh_plugin() {
  local plugin_name="$1"
  local plugin_repo="$2"
  local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/${plugin_name}"

  if [[ ! -d "$plugin_dir" ]]; then
    progress "Cloning '$plugin_name' plugin..."
    if git clone "$plugin_repo" "$plugin_dir" &>>"$LOG_FILE"; then
      success "'$plugin_name' plugin installed"
    else
      error "Failed to clone $plugin_name plugin"
    fi
  else
    success "'$plugin_name' plugin already exists"
  fi
}

validate_input() {
  local input="$1"
  local default="$2"
  echo "${input:-$default}"
}

# -------------------------------#
# START BANNER #
# -------------------------------#

show_banner() {
  log "\n${CYAN}"
  log "██████╗ ███████╗██╗   ██╗███████╗███╗   ██╗██╗   ██╗"
  log "██╔══██╗██╔════╝██║   ██║██╔════╝████╗  ██║██║   ██║"
  log "██║  ██║█████╗  ██║   ██║█████╗  ██╔██╗ ██║██║   ██║"
  log "██║  ██║██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║╚██╗ ██╔╝"
  log "██████╔╝███████╗ ╚████╔╝ ███████╗██║ ╚████║ ╚████╔╝ "
  log "╚═════╝ ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝  ╚═══╝  "
  log "\n Starting development environment setup...${NC}\n"
  info "Log file: $LOG_FILE"
}

# -------------------------------#
# OS CHECK #
# -------------------------------#

check_os() {
  progress "Detecting OS..."

  if [[ "$(uname)" != "Linux" ]]; then
    error "Unsupported OS: $(uname)"
  fi

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "$NAME" != "Ubuntu" && "$NAME" != "Debian GNU/Linux" ]]; then
      error "Unsupported distribution: $NAME"
    fi
    success "OS detected: $NAME"
  else
    error "Cannot detect OS distribution"
  fi
}

# -------------------------------#
# CHECK ZSH AS DEFAULT #
# -------------------------------#

setup_zsh() {
  progress "Verifying if ZSH is default shell..."

  if [[ -z "${ZSH_VERSION:-}" ]]; then
    warning "ZSH is not the current shell. Switching..."

    if ! check_command zsh; then
      sudo_log apt update || error "Failed to update package list"
      install_package zsh
    else
      success "ZSH already installed at $(command -v zsh)"
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"
    progress "Setting ZSH as your default shell..."

    if sudo_log chsh -s "$zsh_path" "$USER"; then
      success "Default shell changed to ZSH"
    else
      error "Failed to change default shell"
    fi

    [[ ! -f "$HOME/.zshrc" ]] && echo "# .zshrc placeholder" > "$HOME/.zshrc"

    if [[ "${SCRIPT_ALREADY_RESTARTED:-}" != "true" ]]; then
      info "Restarting script in ZSH..."
      export SCRIPT_ALREADY_RESTARTED="true"
      exec zsh -c "source \"$0\""
    fi
  else
    success "Currently running inside ZSH"
  fi
}

# -------------------------------#
# USER INFO FOR GIT #
# -------------------------------#

get_user_info() {
  echo -n "Enter your complete name: "
  read -r git_complete_name
  git_complete_name=$(validate_input "$git_complete_name" "Developer")

  echo -n "Enter your email: "
  read -r user_email
  user_email=$(validate_input "$user_email" "developer@example.com")

  info "Using: $git_complete_name <$user_email>"
}

# -------------------------------#
# LOCALE SETUP #
# -------------------------------#

setup_locale() {
  progress "Setting up system locale (en_US.UTF-8)..."

  if locale -a 2>/dev/null | grep -q "en_US.utf8\|en_US.UTF-8"; then
    success "en_US.UTF-8 locale already installed"
  else
    progress "Installing en_US.UTF-8 locale..."

    if ! dpkg -l 2>/dev/null | grep -q "^ii  locales "; then
      install_package locales
    fi

    if sudo_log locale-gen en_US.UTF-8; then
      success "en_US.UTF-8 locale generated"
    else
      warning "Failed to generate en_US.UTF-8 locale"
    fi
  fi

  if sudo_log update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; then
    success "Default locale set to en_US.UTF-8"
  else
    warning "Failed to set default locale"
  fi

  if ! grep -q "export LANG=en_US.UTF-8" "$ZSHRC_FILE" 2>/dev/null; then
    {
      echo ""
      echo "# Locale configuration"
      echo "export LANG=en_US.UTF-8"
      echo "export LC_ALL=en_US.UTF-8"
    } >> "$ZSHRC_FILE"
    success "Locale exports added to ~/.zshrc"
  fi

  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
}

# -------------------------------#
# ESSENTIAL TOOLS INSTALL #
# -------------------------------#

install_essentials() {
  progress "Installing essential tools..."

  sudo_log apt update || error "Failed to update package list"
  sudo_log apt upgrade -y || warning "Some packages failed to upgrade"

  local packages=(
  wget curl git gh unzip zip bat xclip make build-essential
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
  libncursesw5-dev libncurses5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
  libffi-dev liblzma-dev libgdbm-dev libnss3-dev libexpat1-dev
  fontconfig locales pkg-config gcc g++ libclang-dev libcurl4-openssl-dev
  libjpeg-dev libicu-dev fzf ripgrep fd-find libonig-dev libtidy-dev
  libzip-dev libxslt1-dev libpng-dev libwebp-dev libglib2.0-0t64 libgl1
  )

  for package in "${packages[@]}"; do
    if ! dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
      install_package "$package"
    fi
  done

  sudo_log apt clean
  sudo_log apt autoremove -y

  success "Essential tools installed"
}

# -------------------------------#
# DEV TOOLS INSTALLATION #
# -------------------------------#

install_dev_tools() {
  progress "Installing development tools..."

  if [[ ! -d "$HOME/.pyenv" ]]; then
    if curl -fsSL https://pyenv.run | bash &>>"$LOG_FILE"; then
      success "PYENV installed"
    else
      warning "Failed to install PYENV"
    fi
  else
    success "PYENV already installed"
  fi

  if [[ ! -d "$HOME/.fnm" ]]; then
    if curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$HOME/.fnm" --skip-shell &>>"$LOG_FILE"; then
      success "FNM installed"
    else
      warning "Failed to install FNM"
    fi
  else
    success "FNM already installed"
  fi

  if [[ ! -d "$HOME/.sdkman" ]]; then
    if curl -s "https://get.sdkman.io?ci=true" | bash &>>"$LOG_FILE"; then
      success "SDKMAN installed"
    else
      warning "Failed to install SDKMAN"
    fi
  else
    success "SDKMAN already installed"
  fi

  if [[ ! -d "$HOME/.cargo" ]]; then
    if curl https://sh.rustup.rs -sSf | sh -s -- -y &>>"$LOG_FILE"; then
      success "CARGO installed"
    else
      warning "Failed to install CARGO"
    fi
  else
    success "CARGO already installed"
  fi
}

# -------------------------------#
# ERDTREE (via cargo) #
# -------------------------------#

install_erdtree() {
  progress "Installing erdtree..."

  export PATH="$HOME/.cargo/bin:$PATH"

  if check_command erd; then
    success "erdtree already installed: $(erd --version)"
  else
    if ! check_command cargo; then
      warning "Cargo not available, skipping erdtree installation"
      return
    fi

    if cargo install erdtree &>>"$LOG_FILE"; then
      success "erdtree installed"
    else
      warning "Failed to install erdtree"
    fi
  fi

  configure_erdtree
}

# -------------------------------#
# ERDTREE CONFIGURATION #
# -------------------------------#

configure_erdtree() {
  local config_dir="$HOME/.config/erdtree"
  local config_file="$config_dir/.erdtree.toml"

  progress "Configuring erdtree..."

  mkdir -p "$config_dir"

  cat > "$config_file" << 'EOF'
icons = true
human = true
hidden = true
level = 2
EOF

  success "erdtree configuration created at $config_file"
}

# -------------------------------#
# AWS CLI #
# -------------------------------#

install_aws_cli() {
  progress "Installing AWS CLI..."

  if check_command aws; then
    success "AWS CLI already installed: $(aws --version)"
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp_dir/awscliv2.zip" &&
    unzip -q "$tmp_dir/awscliv2.zip" -d "$tmp_dir" &>>"$LOG_FILE" &&
    sudo_log "$tmp_dir/aws/install"; then
    success "AWS CLI installed: $(aws --version)"
  else
    warning "Failed to install AWS CLI"
  fi

  rm -rf "$tmp_dir"
}

# -------------------------------#
# JAVA (via SDKMAN) #
# -------------------------------#

install_java() {
  progress "Installing Java LTS via SDKMAN..."

  local sdkman_init="$HOME/.sdkman/bin/sdkman-init.sh"

  if [[ ! -s "$sdkman_init" ]]; then
    warning "SDKMAN not available, skipping Java installation"
    return
  fi

  set +euo pipefail
  # shellcheck disable=SC1090
  source "$sdkman_init"

  if sdk current java &>/dev/null; then
    local current_java
    current_java="$(sdk current java 2>/dev/null | awk '{print $NF}')"
    success "Java already installed: $current_java"
  else
    if yes | sdk install java &>>"$LOG_FILE"; then
      local installed_java
      installed_java="$(sdk current java 2>/dev/null | awk '{print $NF}')"
      success "Java installed: $installed_java"
    else
      warning "Failed to install Java via SDKMAN"
    fi
  fi

  set -euo pipefail
}

# -------------------------------#
# OH-MY-ZSH + PLUGINS #
# -------------------------------#

setup_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    progress "Installing Oh My Zsh..."
    if git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" &>>"$LOG_FILE"; then
      success "Oh My Zsh installed"
    else
      error "Failed to install Oh My Zsh"
    fi
  else
    success "Oh My Zsh already installed"
  fi

  local plugins=(
  "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git"
  "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git"
  "you-should-use https://github.com/MichaelAquilina/zsh-you-should-use.git"
  "zsh-bat https://github.com/fdellwing/zsh-bat.git"
  "zsh-completions https://github.com/zsh-users/zsh-completions.git"
  )

  for plugin_info in "${plugins[@]}"; do
    local plugin_name plugin_repo
    plugin_name="${plugin_info%% *}"
    plugin_repo="${plugin_info#* }"
    clone_zsh_plugin "$plugin_name" "$plugin_repo"
  done
}

# -------------------------------#
# ZSH CONFIG FILE #
# -------------------------------#

create_zshrc() {
  progress "Creating ZSH configuration..."

  # shellcheck disable=SC2016
  cat > "$ZSHRC_FILE" << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=5"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions you-should-use zsh-bat)
source "$ZSH/oh-my-zsh.sh"

# Aliases
alias ls="erd"
alias l="ls"

# PYENV (Python)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# FNM (Node.js)
export FNM_ROOT="$HOME/.fnm"
if [[ -d $FNM_ROOT ]]; then
    export PATH="$FNM_ROOT:$PATH"
    if command -v fnm 1>/dev/null 2>&1; then
        eval "$("$FNM_ROOT/fnm" env --use-on-cd --version-file-strategy=recursive --shell zsh)"
        fnm use --install-if-missing lts-latest 1>/dev/null 2>&1 || true
    fi
fi

# SDKMAN (Java)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# CARGO (Rust)
export CARGO_ROOT="$HOME/.cargo"
[[ -d "$CARGO_ROOT/bin" ]] && export PATH="$CARGO_ROOT/bin:$PATH"
EOF

  success "ZSH configuration created"
}

# -------------------------------#
# PYTHON SETUP #
# -------------------------------#

setup_python() {
  progress "Setting up Python $PYTHON_VERSION..."

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"

  if ! command -v pyenv &>/dev/null; then
    warning "Pyenv not available for Python setup"
    return
  fi

  eval "$(pyenv init -)"

  if pyenv versions 2>/dev/null | grep -q "$PYTHON_VERSION"; then
    info "Python $PYTHON_VERSION already installed"
  else
    if [[ -d "$PYENV_ROOT/versions/$PYTHON_VERSION" ]]; then
      rm -rf "$PYENV_ROOT/versions/$PYTHON_VERSION"
    fi

    if ! pyenv install "$PYTHON_VERSION" &>>"$LOG_FILE"; then
      error "Failed to install Python $PYTHON_VERSION. Check $LOG_FILE for details."
    fi
  fi

  if pyenv global "$PYTHON_VERSION" &>>"$LOG_FILE"; then
    success "Python $PYTHON_VERSION set as global version"
  else
    warning "Failed to set Python $PYTHON_VERSION as global"
  fi

  local python_version_output
  python_version_output="$(python --version 2>&1)"

  if [[ "$python_version_output" != *"$PYTHON_VERSION"* ]]; then
    warning "Python installation may be incomplete"
    return
  fi

  success "Python verification: $python_version_output"

  if python -m ensurepip --upgrade &>>"$LOG_FILE" 2>&1; then
    success "pip ensured"
  else
    warning "Failed to ensure pip, trying alternative method"
    curl -sS https://bootstrap.pypa.io/get-pip.py | python &>>"$LOG_FILE" || warning "Failed to install pip"
  fi

  if command -v pip &>/dev/null; then
    pip install --upgrade pip &>>"$LOG_FILE" && success "pip upgraded"
    python -m pip install setuptools wheel &>>"$LOG_FILE" && success "setuptools and wheel installed"
  else
    warning "pip not available after Python installation"
  fi
}

# -------------------------------#
# NODE SETUP #
# -------------------------------#

setup_node() {
  progress "Setting up Node.js LTS..."

  local fnm_root="$HOME/.fnm"
  if [[ ! -d "$fnm_root" ]] || [[ ! -x "$fnm_root/fnm" ]]; then
    warning "FNM not available for Node.js setup"
    return
  fi

  export PATH="$fnm_root:$PATH"
  eval "$("$fnm_root/fnm" env --shell bash)"

  if "$fnm_root/fnm" install --lts &>>"$LOG_FILE"; then
    local node_version
    node_version="$("$fnm_root/fnm" current 2>/dev/null || echo "unknown")"
    success "Node.js LTS installed: $node_version"
  else
    warning "Failed to install Node.js LTS"
  fi
}

# -------------------------------#
# SSH SETUP #
# -------------------------------#

setup_ssh() {
  progress "Setting up SSH..."

  mkdir -p ~/.ssh
  chmod 700 ~/.ssh

  local ssh_key_path="$HOME/.ssh/$GIT_SSH_KEY_NAME"

  if [[ ! -f "$ssh_key_path" ]]; then
    if ssh-keygen -t ed25519 -C "$user_email" -f "$ssh_key_path" -N "" &>>"$LOG_FILE"; then
      success "SSH key generated"
    else
      error "Failed to generate SSH key"
    fi
  else
    success "SSH key already exists"
  fi

  if [[ -z "${SSH_AGENT_PID:-}" ]]; then
    eval "$(ssh-agent -s)" &>>"$LOG_FILE"
  fi

  if ssh-add "$ssh_key_path" &>>"$LOG_FILE"; then
    success "SSH key added to agent"
  else
    warning "Failed to add SSH key to agent"
  fi

  cat > ~/.ssh/config << EOF
Host github.com
  HostName github.com
  PreferredAuthentications publickey
  AddKeysToAgent yes
  IdentityFile ~/.ssh/$GIT_SSH_KEY_NAME

Host bitbucket.org
  HostName bitbucket.org
  PreferredAuthentications publickey
  AddKeysToAgent yes
  IdentityFile ~/.ssh/$GIT_SSH_KEY_NAME
EOF

  chmod 600 ~/.ssh/config
  success "SSH configuration created"

  if check_command xclip; then
    if xclip -selection clipboard < "${ssh_key_path}.pub"; then
      success "SSH key copied to clipboard"
    else
      warning "Failed to copy SSH key to clipboard"
    fi
  else
    warning "xclip not available — copy key manually from: ${ssh_key_path}.pub"
  fi
}

# -------------------------------#
# GIT CONFIG #
# -------------------------------#

configure_git() {
  progress "Configuring global Git settings..."

  if ! check_command git; then
    error "Git is not installed or not found in PATH."
  fi

  success "Git is installed: $(git --version)"

  git config --global user.name "$git_complete_name"
  git config --global user.email "$user_email"
  git config --global core.editor "code --wait"
  git config --global core.excludesfile "$HOME/.gitignore"
  git config --global init.defaultbranch "main"
  git config --global core.fileMode false
  git config --global --add safe.directory '*'
  git config --global core.autocrlf input
  git config --global pull.rebase false

  cat > ~/.gitignore << 'EOF'
# Dependencies
node_modules/
.pnp
.pnp.js

# Build outputs
.next/
dist/
build/
out/

# Environment files
.env*
!.env.example

# IDE
.vscode/
.cursor/
.idea/
.kiro/
.amazonq/

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Package manager
.npmrc
*-lock.json
yarn.lock
pnpm-lock.yaml

# Version files
.nvmrc
.node-version
.python-version

# Misc
.eslint*
*.gyp
EOF

  touch ~/.hushlogin
  success "Global Git configuration completed"
}

# -------------------------------#
# CLEANUP #
# -------------------------------#

cleanup() {
  progress "Cleaning up..."

  local script_folder
  script_folder="$(basename "$SCRIPT_DIR")"

  if [[ "$script_folder" == "devenv-setup" ]]; then
    if rm -rf "$SCRIPT_DIR"; then
      success "Cleaned up $SCRIPT_DIR"
    else
      warning "Failed to clean up"
    fi
  else
    info "Script not inside devenv-setup/, skipping cleanup"
  fi
}

# -------------------------------#
# MAIN FUNCTION #
# -------------------------------#

main() {
  show_banner
  check_os
  setup_zsh
  get_user_info
  setup_locale
  install_essentials
  install_dev_tools
  install_erdtree
  install_aws_cli
  install_java
  setup_oh_my_zsh
  create_zshrc
  setup_python
  setup_node
  setup_ssh
  configure_git
  cleanup

  success "Environment setup completed!"
  info "Configuration summary:"
  info "  Locale: en_US.UTF-8"
  info "  Shell: ZSH with Oh My Zsh"
  info "  Python: $PYTHON_VERSION (via pyenv)"
  info "  Node.js: LTS (via fnm)"
  info "  Java: LTS (via SDKMAN)"
  info "  Rust + erdtree (via cargo)"
  info "  AWS CLI v2"
  info "Please restart your terminal (WSL) or session (Linux) to apply changes"
  info "Log file: $LOG_FILE"
}

# -------------------------------#
# SCRIPT EXECUTION #
# -------------------------------#

if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
  main "$@"
fi
