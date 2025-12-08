#!/bin/bash

# Check latest Chromium versions across all release channels
# This script examines git tags to identify the newest version in each channel

set -e

echo "🔍 Checking Chromium versions across all channels..."
echo ""

cd ~/chromium/src

# Define colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get current version
CURRENT_VERSION=$(git describe --tags 2>/dev/null || echo "unknown")
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

echo "📍 Current State:"
echo "   Branch:  $CURRENT_BRANCH"
echo "   Version: $CURRENT_VERSION"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to get latest version for a major version number
get_latest_for_major() {
    local major=$1
    git tag | grep -E "^${major}\." | sort -V | tail -1
}

# Function to extract major version number
get_major() {
    echo "$1" | cut -d. -f1
}

# Get all unique major versions
echo "🔎 Scanning for all major versions..."
ALL_MAJORS=$(git tag | grep -E '^\d+\.\d+\.\d+' | cut -d. -f1 | sort -nu | tail -20)

echo ""
echo "📊 Latest versions by major release:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Track the absolute latest versions
LATEST_STABLE=""
LATEST_BETA=""
LATEST_DEV=""
LATEST_CANARY=""

for major in $ALL_MAJORS; do
    latest=$(get_latest_for_major "$major")
    
    # Count dots to determine version format
    dots=$(echo "$latest" | tr -cd '.' | wc -c | tr -d ' ')
    
    # Determine channel based on version pattern
    # Stable: 4-part versions with higher patch numbers (e.g., 142.0.7444.134)
    # Beta: 4-part versions with lower patch numbers (e.g., 142.0.7444.28)
    # Dev/Canary: 3-part versions (e.g., 143.0.7468.1)
    
    if [ "$dots" -eq 3 ]; then
        # 4-part version
        # Extract the last part (patch number)
        patch=$(echo "$latest" | cut -d. -f4)
        
        # Heuristic: patch numbers >= 100 are typically stable releases
        # Stable releases get many security/bug fix updates
        if [ "$patch" -ge 100 ]; then
            channel="${GREEN}STABLE${NC}"
            LATEST_STABLE="$latest"
        else
            channel="${CYAN}BETA${NC}"
            LATEST_BETA="$latest"
        fi
    else
        # 3-part version (e.g., 143.0.7468.1) - development builds
        if [ $major -ge 143 ]; then
            channel="${YELLOW}CANARY${NC}"
            LATEST_CANARY="$latest"
        else
            channel="${BLUE}DEV${NC}"
            LATEST_DEV="$latest"
        fi
    fi
    
    echo -e "   v$major → $latest  [$channel]"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Summary of latest by channel
echo "📢 Latest Versions by Channel:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ -n "$LATEST_STABLE" ] && echo -e "   ${GREEN}STABLE:${NC}  $LATEST_STABLE"
[ -n "$LATEST_BETA" ] && echo -e "   ${CYAN}BETA:${NC}    $LATEST_BETA"
[ -n "$LATEST_DEV" ] && echo -e "   ${BLUE}DEV:${NC}     $LATEST_DEV"
[ -n "$LATEST_CANARY" ] && echo -e "   ${YELLOW}CANARY:${NC}  $LATEST_CANARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Compare with current
CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | grep -oE '^\d+' || echo "0")

echo "💡 Recommendations:"
echo ""
if [ -n "$LATEST_STABLE" ]; then
    STABLE_MAJOR=$(get_major "$LATEST_STABLE")
    if [ "$CURRENT_MAJOR" -lt "$STABLE_MAJOR" ]; then
        echo -e "   ${GREEN}✓${NC} You can upgrade to stable: $LATEST_STABLE"
        echo "     Command: git checkout $LATEST_STABLE"
    elif [ "$CURRENT_MAJOR" -eq "$STABLE_MAJOR" ]; then
        echo -e "   ${GREEN}✓${NC} You're on the same stable major version ($STABLE_MAJOR)"
    else
        echo -e "   ${YELLOW}→${NC} You're ahead of stable (current: v$CURRENT_MAJOR, stable: v$STABLE_MAJOR)"
    fi
fi

echo ""
echo "📝 Notes:"
echo "   • STABLE: Recommended for production use"
echo "   • BETA: Preview of upcoming stable release"
echo "   • DEV: Development builds, updated frequently"
echo "   • CANARY: Bleeding edge, daily builds"
echo ""
echo "🧪 To test patches on latest stable:"
echo "   ./test_patches_on_latest.sh"
echo ""
echo "🔄 To upgrade to a specific version:"
echo "   cd ~/chromium/src"
echo "   git checkout <version-tag>"
echo "   gclient sync"
echo "   # Then apply patches and rebuild"
echo ""
