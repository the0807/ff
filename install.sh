#!/usr/bin/env bash

set -e

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Installation configuration ---
INSTALL_DIR="$HOME/.config/ff"
REPO_BASE_URL="https://raw.githubusercontent.com/the0807/ff/main"

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
OPTIONAL_TOOLS=("rg" "eza" "tree")
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

# Check fd/fdfind separately (either one is fine)
if command -v fd >/dev/null 2>&1; then
    FOUND_TOOLS+=("fd")
elif command -v fdfind >/dev/null 2>&1; then
    FOUND_TOOLS+=("fdfind")
else
    MISSING_TOOLS+=("fd(fdfind)")
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

# --- 2. Detect Shell & Config File (Robust) ---
echo ""
echo -e "${BLUE}[2/5]${NC} Detecting shell..."

USER_SHELL=$(basename "$SHELL")
SHELL_CONFIG=""
INSTALL_FILE=""
REPO_URL=""

case "$USER_SHELL" in
    zsh)
        SHELL_NAME="zsh"
        SHELL_CONFIG="$HOME/.zshrc"
        INSTALL_FILE="$INSTALL_DIR/ff.sh"
        REPO_URL="$REPO_BASE_URL/ff.sh"
        ;;
    bash)
        SHELL_NAME="bash"
        INSTALL_FILE="$INSTALL_DIR/ff.sh"
        REPO_URL="$REPO_BASE_URL/ff.sh"
        if [[ "$OSTYPE" == "darwin"* && -f "$HOME/.bash_profile" ]]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.bashrc"
        fi
        ;;
    fish)
        SHELL_NAME="fish"
        SHELL_CONFIG="$HOME/.config/fish/config.fish"
        INSTALL_FILE="$INSTALL_DIR/ff.fish"
        REPO_URL="$REPO_BASE_URL/ff.fish"
        # Ensure fish config directory exists
        mkdir -p "$HOME/.config/fish"
        ;;
    *)
        echo -e "${YELLOW}⚠${NC} Could not auto-detect shell type (Current: $USER_SHELL)."
        echo "Supported shells: bash, zsh, fish"
        echo ""
        echo "For bash/zsh, manually add this line to your config file:"
        echo "  source $INSTALL_DIR/ff.sh"
        echo ""
        echo "For fish, manually add this line to ~/.config/fish/config.fish:"
        echo "  source $INSTALL_DIR/ff.fish"
        exit 0
        ;;
esac

echo -e "${GREEN}✓${NC} Detected shell: $SHELL_NAME"
echo -e "${GREEN}✓${NC} Target config: $SHELL_CONFIG"
echo -e "${GREEN}✓${NC} Install file: $INSTALL_FILE"

# --- 3. Create installation directory ---
echo ""
echo -e "${BLUE}[3/5]${NC} Creating installation directory..."
mkdir -p "$INSTALL_DIR"
echo -e "${GREEN}✓${NC} Directory created: $INSTALL_DIR"

# --- 4. Download script (curl/wget fallback) ---
echo ""
echo -e "${BLUE}[4/5]${NC} Downloading script..."

if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$REPO_URL" -o "$INSTALL_FILE"; then
        echo -e "${GREEN}✓${NC} Downloaded (via curl): $(basename $INSTALL_FILE)"
    else
        echo -e "${RED}✗${NC} Download failed using curl"
        exit 1
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$INSTALL_FILE" "$REPO_URL"; then
        echo -e "${GREEN}✓${NC} Downloaded (via wget): $(basename $INSTALL_FILE)"
    else
        echo -e "${RED}✗${NC} Download failed using wget"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Neither curl nor wget found."
    exit 1
fi

chmod +x "$INSTALL_FILE"

# --- 5. Add to shell config (with Backup) ---
echo ""
echo -e "${BLUE}[5/5]${NC} Updating configuration..."

SOURCE_LINE="source $INSTALL_FILE"

if grep -Fq "$SOURCE_LINE" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}i${NC} Already configured in $SHELL_CONFIG"
else
    # Create backup
    if [ -f "$SHELL_CONFIG" ]; then
        cp "$SHELL_CONFIG" "${SHELL_CONFIG}.bak"
        echo -e "${GREEN}✓${NC} Created backup at ${SHELL_CONFIG}.bak"
    fi

    # Add to config file
    echo "" >> "$SHELL_CONFIG"
    echo "# ff - Flexible File Finder" >> "$SHELL_CONFIG"

    if [ "$SHELL_NAME" = "fish" ]; then
        # Fish uses 'source' command
        echo "source $INSTALL_FILE" >> "$SHELL_CONFIG"
    else
        # Bash/Zsh use 'source' command
        echo "source $INSTALL_FILE" >> "$SHELL_CONFIG"
    fi

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
