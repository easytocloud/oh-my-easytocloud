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

# Update .zshrc
echo "⚙️  Configuring .zshrc..."
ZSHRC="$HOME/.zshrc"

# Set theme
if grep -q '^ZSH_THEME=' "$ZSHRC"; then
    # Safe approach: create temp file then replace
    sed 's/^ZSH_THEME=.*/ZSH_THEME="easytocloud"/' "$ZSHRC" > "$ZSHRC.tmp"
    cat "$ZSHRC.tmp" > "$ZSHRC"
    rm "$ZSHRC.tmp"
else
    echo 'ZSH_THEME="easytocloud"' >> "$ZSHRC"
fi

# Add plugin auto-loader BEFORE oh-my-zsh.sh sourcing
if ! grep -q 'easytocloud.*plugins' "$ZSHRC"; then
    # Find the line that sources oh-my-zsh.sh
    if grep -q 'source.*oh-my-zsh.sh' "$ZSHRC"; then
        # Insert plugin loader before the source line
        sed -i.bak '/source.*oh-my-zsh.sh/i\
# Auto-add easytocloud plugin if not already present\
[[ " ${plugins[*]} " =~ " easytocloud " ]] || plugins=( $plugins easytocloud )\
' "$ZSHRC"
    else
        # Fallback: add at end if source line not found
        echo '' >> "$ZSHRC"
        echo '# Auto-add easytocloud plugin if not already present' >> "$ZSHRC"
        echo '[[ " ${plugins[*]} " =~ " easytocloud " ]] || plugins=( $plugins easytocloud )' >> "$ZSHRC"
    fi
fi

# Add AWS_ENV auto-detection
if ! grep -q 'AWS_ENV.*age' "$ZSHRC"; then
    echo '' >> "$ZSHRC"
    echo '# Auto-detect AWS_ENV using age() function' >> "$ZSHRC"
    echo '_aws_env=$(age 2>/dev/null) && [[ -n "$_aws_env" ]] && export AWS_ENV="$_aws_env"' >> "$ZSHRC"
fi

echo "✅ Installation complete!"
echo "🔄 Please restart your terminal or run: source ~/.zshrc"