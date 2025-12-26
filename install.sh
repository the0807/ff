#!/usr/bin/env bash

set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Installation configuration ---
INSTALL_DIR="$HOME"
INSTALL_FILE="$INSTALL_DIR/.ff.sh"
REPO_URL="https://raw.githubusercontent.com/the0807/ff/main/ff.sh"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🔍 ff - Flexible File Finder Installer   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# --- 1. Check for fzf (Required) ---
echo -e "${BLUE}[1/4]${NC} Checking dependencies..."
if ! command -v fzf >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} fzf is not installed!"
    echo ""
    echo "fzf is required for ff to work."
    exit 1
fi
echo -e "${GREEN}✓${NC} fzf found"

# --- Check optional dependencies ---
OPTIONAL_TOOLS=("fd" "rg" "eza" "tree")
FOUND_TOOLS=()
MISSING_TOOLS=()

# Check bat/batcat separately (either one is fine)
if command -v batcat >/dev/null 2>&1; then
    FOUND_TOOLS+=("batcat")
elif command -v bat >/dev/null 2>&1; then
    FOUND_TOOLS+=("bat")
else
    MISSING_TOOLS+=("bat(batcat)")
fi

# Check other optional tools
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        FOUND_TOOLS+=("$tool")
    else
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#FOUND_TOOLS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Optional tools found: ${FOUND_TOOLS[*]}"
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}i${NC} Optional tools missing: ${MISSING_TOOLS[*]}"
    echo -e "  ${YELLOW}(Install these for better experience)${NC}"
fi

# --- 2. Download ff.sh (curl/wget fallback) ---
echo ""
echo -e "${BLUE}[2/4]${NC} Downloading ff.sh..."

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$REPO_URL" -o "$INSTALL_FILE"; then
        echo -e "${GREEN}✓${NC} Downloaded (via curl)"
    else
        echo -e "${RED}✗${NC} Download failed using curl"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$INSTALL_FILE" "$REPO_URL"; then
        echo -e "${GREEN}✓${NC} Downloaded (via wget)"
    else
        echo -e "${RED}✗${NC} Download failed using wget"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Neither curl nor wget found."
    exit 1
fi

chmod +x "$INSTALL_FILE"

# --- 3. Detect Shell & Config File (Robust) ---
echo ""
echo -e "${BLUE}[3/4]${NC} Configuring shell..."

USER_SHELL=$(basename "$SHELL")
SHELL_CONFIG=""

case "$USER_SHELL" in
    zsh)
        SHELL_NAME="zsh"
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
    bash)
        SHELL_NAME="bash"
        if [[ "$OSTYPE" == "darwin"* && -f "$HOME/.bash_profile" ]]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
        ;;
    *)
        echo -e "${YELLOW}⚠${NC} Could not auto-detect shell type (Current: $USER_SHELL)."
        echo "Please manually add this line to your config file:"
        echo "  source $INSTALL_FILE"
        exit 0
        ;;
esac

echo -e "${GREEN}✓${NC} Detected shell: $SHELL_NAME"
echo -e "${GREEN}✓${NC} Target config: $SHELL_CONFIG"

# --- 4. Add to shell config (with Backup) ---
echo ""
echo -e "${BLUE}[4/4]${NC} Updating configuration..."

SOURCE_LINE="source $INSTALL_FILE"

if grep -Fq "$SOURCE_LINE" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}i${NC} Already configured in $SHELL_CONFIG"
else
    # Create backup
    if [ -f "$SHELL_CONFIG" ]; then
        cp "$SHELL_CONFIG" "${SHELL_CONFIG}.bak"
        echo -e "${GREEN}✓${NC} Created backup at ${SHELL_CONFIG}.bak"
    fi

    echo "" >> "$SHELL_CONFIG"
    echo "# ff - Flexible File Finder" >> "$SHELL_CONFIG"
    echo "$SOURCE_LINE" >> "$SHELL_CONFIG"
    echo -e "${GREEN}✓${NC} Added to $SHELL_CONFIG"
fi

# --- Success Message ---
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✓ Installation completed! 🎉       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "To start using ff, run:"
echo -e "  ${BLUE}source $SHELL_CONFIG${NC}"
echo ""
