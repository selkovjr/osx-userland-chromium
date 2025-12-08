#!/bin/bash

# Test if patches apply cleanly to latest stable Chromium release
# This script creates a test branch and attempts to apply all patches

set -e

echo "🔍 Testing patch compatibility with latest stable Chromium..."
echo ""

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script's directory to find patches
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"

# Check if patches directory exists
if [ ! -d "$PATCHES_DIR" ]; then
    echo -e "${RED}❌ Patches directory not found at: $PATCHES_DIR${NC}"
    exit 1
fi

cd ~/chromium/src

# Find the latest stable version (142.x series)
LATEST_STABLE=$(git tag | grep -E '^142\.' | sort -V | tail -1)
CURRENT_VERSION=$(git describe --tags 2>/dev/null || echo "unknown")

echo "📊 Version Information:"
echo "   Current version: $CURRENT_VERSION"
echo "   Latest stable:   $LATEST_STABLE"
echo ""

# Create a test branch
TEST_BRANCH="test-patches-${LATEST_STABLE}"
echo "🌿 Creating test branch: $TEST_BRANCH"

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️  Uncommitted changes detected. Stashing..."
    git stash push -m "auto-stash for patch testing at $(date)"
    STASHED=true
else
    STASHED=false
fi

# Clean up any existing test branch
git branch -D "$TEST_BRANCH" 2>/dev/null || true

# Create and checkout new test branch from the latest stable tag
git checkout -b "$TEST_BRANCH" "$LATEST_STABLE"

echo ""
echo "📦 Testing patches..."
echo ""

# Array to track results
declare -a PATCH_RESULTS

# Test each patch
PATCHES=(
    "user-agent.patch"
    "private-network.patch"
    "omnibox-multiclick.patch"
    "session-restore.patch"
    "tab-search-url.patch"
)

echo "   Using patches from: $PATCHES_DIR"
echo ""

for patch in "${PATCHES[@]}"; do
    PATCH_PATH="$PATCHES_DIR/$patch"
    
    if [ ! -f "$PATCH_PATH" ]; then
        echo -e "${YELLOW}⚠️  $patch - NOT FOUND${NC}"
        PATCH_RESULTS+=("$patch: NOT FOUND")
        continue
    fi
    
    echo -n "   Testing $patch... "
    
    # Try to apply the patch (dry run first)
    if git apply --check "$PATCH_PATH" 2>/dev/null; then
        echo -e "${GREEN}✅ APPLIES CLEANLY${NC}"
        PATCH_RESULTS+=("$patch: ✅ APPLIES CLEANLY")
        
        # Actually apply it for next patch test
        git apply "$PATCH_PATH"
    else
        echo -e "${RED}❌ CONFLICTS${NC}"
        PATCH_RESULTS+=("$patch: ❌ CONFLICTS")
        
        # Show what failed
        echo ""
        echo -e "${YELLOW}Conflict details for $patch:${NC}"
        git apply --check "$PATCH_PATH" 2>&1 | head -20
        echo ""
    fi
done

echo ""
echo "📋 Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${PATCH_RESULTS[@]}"; do
    echo "   $result"
done
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🔄 Returning to original branch..."
git checkout -

# Restore stashed changes if we stashed them
if [ "$STASHED" = true ]; then
    echo "📦 Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "💡 Tips:"
echo "   • If patches apply cleanly, you can upgrade to $LATEST_STABLE"
echo "   • If patches conflict, review changes with:"
echo "     git diff $CURRENT_VERSION..$LATEST_STABLE -- chrome/browser/ui/views/omnibox/"
echo "   • The test branch '$TEST_BRANCH' has been left for inspection"
echo "   • Delete it when done with: git branch -D $TEST_BRANCH"
echo ""
