#!/usr/bin/env bash

set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Uninstallation configuration ---
INSTALL_DIR="$HOME/.config/ff"
BACKUP_SUFFIX=".ff_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🗑️  ff - Flexible File Finder Uninstaller ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# --- 1. Confirmation prompt ---
echo -e "${YELLOW}⚠️  This will remove ff from your system.${NC}"
echo ""
echo "The following will be removed:"
echo "  - Installation directory: $INSTALL_DIR"
echo "  - Source lines from shell configuration files"
echo ""
read -p "Do you want to continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Uninstallation cancelled.${NC}"
    exit 0
fi

echo ""

# --- 2. Remove installation directory ---
echo -e "${BLUE}[1/3]${NC} Removing installation directory..."

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Removed: $INSTALL_DIR"
else
    echo -e "${YELLOW}i${NC} Directory not found: $INSTALL_DIR"
fi

# --- 3. Detect and clean shell configurations ---
echo ""
echo -e "${BLUE}[2/3]${NC} Cleaning shell configuration files..."

USER_SHELL=$(basename "$SHELL")
CLEANED_FILES=0

# Function to remove ff lines from a config file
remove_ff_lines() {
    local config_file="$1"
    local source_pattern="$2"

    if [ ! -f "$config_file" ]; then
        return
    fi

    # Check if ff is configured
    if ! grep -q "$source_pattern" "$config_file" 2>/dev/null; then
        return
    fi

    # Create backup
    cp "$config_file" "${config_file}${BACKUP_SUFFIX}"
    echo -e "${GREEN}✓${NC} Created backup: ${config_file}${BACKUP_SUFFIX}"

    # Remove ff-related lines (comment line + source line)
    sed -i.tmp '/# ff - Flexible File Finder/d; \|'"$source_pattern"'|d' "$config_file"
    rm -f "${config_file}.tmp"

    echo -e "${GREEN}✓${NC} Cleaned: $config_file"
    CLEANED_FILES=$((CLEANED_FILES + 1))
}

# Clean Bash configuration
if [ -f "$HOME/.bashrc" ]; then
    remove_ff_lines "$HOME/.bashrc" "source.*/.config/ff/ff.sh"
fi

if [ -f "$HOME/.bash_profile" ]; then
    remove_ff_lines "$HOME/.bash_profile" "source.*/.config/ff/ff.sh"
fi

# Clean Zsh configuration
if [ -f "$HOME/.zshrc" ]; then
    remove_ff_lines "$HOME/.zshrc" "source.*/.config/ff/ff.sh"
fi

# Clean Fish configuration
if [ -f "$HOME/.config/fish/config.fish" ]; then
    remove_ff_lines "$HOME/.config/fish/config.fish" "source.*/.config/ff/ff.fish"
fi

if [ $CLEANED_FILES -eq 0 ]; then
    echo -e "${YELLOW}i${NC} No ff configuration found in shell config files"
fi

# --- 4. Final message ---
echo ""
echo -e "${BLUE}[3/3]${NC} Cleanup complete!"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ Uninstallation completed! 🎉     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

if [ $CLEANED_FILES -gt 0 ]; then
    echo "Backup files created with suffix: ${BACKUP_SUFFIX}"
    echo ""
    echo "To complete the removal, restart your shell or run:"
    case "$USER_SHELL" in
        zsh)
            echo -e "  ${BLUE}source ~/.zshrc${NC}"
            ;;
        bash)
            echo -e "  ${BLUE}source ~/.bashrc${NC}"
            ;;
        fish)
            echo -e "  ${BLUE}source ~/.config/fish/config.fish${NC}"
            ;;
    esac
    echo ""
fi

echo "Thank you for using ff! 👋"
echo ""
