#!/bin/bash
set -e

# oh-my-easytocloud installer
echo "🚀 Installing oh-my-easytocloud..."

# Check if oh-my-zsh is installed
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "❌ Error: oh-my-zsh not found at $HOME/.oh-my-zsh"
    echo "Please install oh-my-zsh first: https://ohmyz.sh/"
    exit 1
fi

# Create directories
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
mkdir -p "$HOME/.oh-my-zsh/custom/plugins/easytocloud"

# Check for --local flag
if [[ "$1" == "--local" ]]; then
    # Install from local files
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    echo "📥 Installing easytocloud theme from local files..."
    cp "$SCRIPT_DIR/themes/easytocloud.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/"
    
    echo "📥 Installing easytocloud plugin from local files..."
    cp "$SCRIPT_DIR/plugins/easytocloud/easytocloud.plugin.zsh" "$HOME/.oh-my-zsh/custom/plugins/easytocloud/"
else
    # Download from GitHub
    echo "📥 Installing easytocloud theme..."
    curl -fsSL https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/themes/easytocloud.zsh-theme \
        -o "$HOME/.oh-my-zsh/custom/themes/easytocloud.zsh-theme"
    
    echo "📥 Installing easytocloud plugin..."
    curl -fsSL https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/plugins/easytocloud/easytocloud.plugin.zsh \
        -o "$HOME/.oh-my-zsh/custom/plugins/easytocloud/easytocloud.plugin.zsh"
fi

echo "✅ Installation complete!"
echo ""
echo "To activate, add to your ~/.zshrc:"
echo "  ZSH_THEME=\"easytocloud\""
echo "  plugins=(... easytocloud ...)"
echo ""
echo "Then restart your terminal or run: source ~/.zshrc"