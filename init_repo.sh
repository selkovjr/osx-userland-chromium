#!/bin/bash

# Repository Initialization Script
# Sets up the osx-userland-chromium repository with proper git configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo_header "Initializing osx-userland-chromium Repository"
echo "Location: $PROJECT_ROOT"
echo

# Initialize git repository if not already done
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo_info "Initializing git repository..."
    cd "$PROJECT_ROOT"
    git init
    
    # Create .gitignore
    cat > .gitignore << 'EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Icon must end with two \r
Icon

# Thumbnails
._*

# Files that might appear in the root of a volume
.DocumentRevisions-V100
.fseventsd
.Spotlight-V100
.TemporaryItems
.Trashes
.VolumeIcon.icns
.com.apple.timemachine.donotpresent

# Directories potentially created on remote AFP share
.AppleDB
.AppleDesktop
Network Trash Folder
Temporary Items
.apdisk

# Build artifacts
*.o
*.a
*.so
*.dylib
build/
out/
Release/
Debug/

# Temporary files
*.tmp
*.temp
*.log
*.swp
*.swo
*~

# Environment files
.env
.env.local
.env.production

# IDE files
.vscode/
.idea/
*.sublime-*

# Node.js (if any scripts use it)
node_modules/
npm-debug.log*

# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
.pytest_cache/

# Test outputs
test_results/
coverage/

# Backup files
*.bak
*.backup
*.old

# Editor temporary files
.#*
#*#

# Chromium specific
.gclient_entries
.cipd/
src/

EOF

    echo_info "✅ Git repository initialized"
else
    echo_info "Git repository already exists"
fi

# Set up git configuration
echo_info "Configuring git repository..."
cd "$PROJECT_ROOT"

# Set up remote if not exists
if ! git remote get-url origin >/dev/null 2>&1; then
    echo_warn "No git remote configured"
    echo_info "To add a remote repository:"
    echo_info "  git remote add origin https://github.com/YOUR_USERNAME/osx-userland-chromium.git"
else
    REMOTE_URL=$(git remote get-url origin)
    echo_info "Git remote configured: $REMOTE_URL"
fi

# Create initial commit if needed
if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo_info "Creating initial commit..."
    
    git add .
    git commit -m "Initial commit: Custom Chromium for macOS with enterprise features

Features:
- Chrome user agent branding for Okta/SAML compatibility
- Private network access bypass for OAuth redirects
- Enhanced double-click text selection in omnibox
- Automatic session restore on startup
- Full macOS GUI integration
- Comprehensive build and installation scripts
- Complete documentation and troubleshooting guides

This repository provides everything needed to build a custom Chromium
browser with enterprise compatibility and enhanced user experience."

    echo_info "✅ Initial commit created"
else
    echo_info "Repository already has commits"
fi

# Verify repository structure
echo_header "Verifying Repository Structure"

REQUIRED_DIRS=(
    "docs"
    "patches"
    "scripts"
    "config"
)

REQUIRED_FILES=(
    "README.md"
    "LICENSE"
    "docs/build-guide.md"
    "docs/code-changes.md"
    "docs/macos-integration.md"
    "docs/enterprise-features.md"
    "docs/troubleshooting.md"
    "patches/user-agent.patch"
    "patches/private-network.patch"
    "patches/double-click.patch"
    "patches/session-restore.patch"
    "scripts/build.sh"
    "scripts/install_macos_gui.sh"
    "scripts/test_features.sh"
    "scripts/restore_session.sh"
    "config/args.gn"
    "config/.gclient"
    "test_features.html"
)

echo_info "Checking required directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo_info "✅ $dir/"
    else
        echo_error "❌ Missing directory: $dir/"
    fi
done

echo_info "Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo_info "✅ $file"
    else
        echo_error "❌ Missing file: $file"
    fi
done

# Make scripts executable
echo_info "Setting script permissions..."
chmod +x "$PROJECT_ROOT"/scripts/*.sh 2>/dev/null || true
echo_info "✅ Scripts made executable"

# Create GitHub workflow directory (optional)
if [ ! -d "$PROJECT_ROOT/.github" ]; then
    echo_info "Creating GitHub workflow directory..."
    mkdir -p "$PROJECT_ROOT/.github/workflows"
    
    # Create basic CI workflow
    cat > "$PROJECT_ROOT/.github/workflows/documentation.yml" << 'EOF'
name: Documentation Check

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  check-docs:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Check documentation structure
      run: |
        echo "Checking documentation structure..."
        
        # Check if all required docs exist
        required_docs=(
          "README.md"
          "docs/build-guide.md"
          "docs/code-changes.md"
          "docs/macos-integration.md"
          "docs/enterprise-features.md"
          "docs/troubleshooting.md"
        )
        
        for doc in "${required_docs[@]}"; do
          if [ ! -f "$doc" ]; then
            echo "❌ Missing: $doc"
            exit 1
          else
            echo "✅ Found: $doc"
          fi
        done
        
        echo "Documentation structure check passed!"
    
    - name: Check patch files
      run: |
        echo "Checking patch files..."
        
        patch_files=(
          "patches/user-agent.patch"
          "patches/private-network.patch"
          "patches/double-click.patch"
          "patches/session-restore.patch"
        )
        
        for patch in "${patch_files[@]}"; do
          if [ ! -f "$patch" ]; then
            echo "❌ Missing: $patch"
            exit 1
          else
            echo "✅ Found: $patch"
          fi
        done
        
        echo "Patch files check passed!"
EOF

    echo_info "✅ GitHub workflows created"
fi

# Display repository information
echo_header "Repository Information"
echo_info "Repository: $(basename "$PROJECT_ROOT")"
echo_info "Location: $PROJECT_ROOT"
echo_info "Files: $(find "$PROJECT_ROOT" -type f | wc -l | xargs)"
echo_info "Directories: $(find "$PROJECT_ROOT" -type d | wc -l | xargs)"

if [ -d "$PROJECT_ROOT/.git" ]; then
    echo_info "Git status:"
    git status --short | head -10
    if [ $(git status --short | wc -l) -gt 10 ]; then
        echo_info "... and $(($(git status --short | wc -l) - 10)) more files"
    fi
fi

echo_header "Next Steps"
echo
echo_info "Repository initialization complete! 🎉"
echo
echo_info "To publish to GitHub:"
echo "  1. Create a new repository on GitHub"
echo "  2. git remote add origin https://github.com/YOUR_USERNAME/osx-userland-chromium.git"
echo "  3. git push -u origin main"
echo
echo_info "To build Chromium:"
echo "  1. Run: ./scripts/build.sh"
echo "  2. Or follow the manual guide: docs/build-guide.md"
echo
echo_info "To test features:"
echo "  1. Open: test_features.html in your custom Chromium"
echo "  2. Run: ./scripts/test_features.sh"
echo
echo_info "For documentation:"
echo "  • Complete guide: README.md"
echo "  • Build instructions: docs/build-guide.md"
echo "  • Technical details: docs/code-changes.md"
echo "  • macOS integration: docs/macos-integration.md"
echo "  • Enterprise features: docs/enterprise-features.md"
echo "  • Troubleshooting: docs/troubleshooting.md"
echo
echo_info "Repository structure verified and ready for use!"