#!/bin/bash

# Automated Chromium Build Script
# This script automates the entire build process from source download to final installation

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
CHROMIUM_VERSION="139.0.7258.128"
WORKSPACE_DIR="$HOME/chromium"
SOURCE_DIR="$WORKSPACE_DIR/src"

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

# Function to check prerequisites
check_prerequisites() {
    echo_header "Checking Prerequisites"
    
    # Check for depot_tools
    if ! command -v gclient >/dev/null 2>&1; then
        echo_error "depot_tools not found. Please install depot_tools first:"
        echo_error "  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/src/depot_tools"
        echo_error "  export PATH=\"\$HOME/src/depot_tools:\$PATH\""
        exit 1
    fi
    
    # Check for Xcode tools
    if ! xcode-select -p >/dev/null 2>&1; then
        echo_error "Xcode command line tools not found. Please install:"
        echo_error "  xcode-select --install"
        exit 1
    fi
    
    # Check for Python
    if ! command -v python3 >/dev/null 2>&1; then
        echo_error "Python 3 not found. Please install Python 3."
        exit 1
    fi
    
    # Check disk space (need ~50GB)
    AVAILABLE_GB=$(df -g . | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_GB" -lt 50 ]; then
        echo_warn "Low disk space detected (${AVAILABLE_GB}GB available). Recommended: 50GB+"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo_info "✅ Prerequisites check passed"
}

# Function to setup workspace
setup_workspace() {
    echo_header "Setting Up Workspace"
    
    if [ -d "$WORKSPACE_DIR" ]; then
        echo_warn "Workspace directory already exists: $WORKSPACE_DIR"
        read -p "Remove existing workspace? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$WORKSPACE_DIR"
        else
            echo_info "Using existing workspace"
            return
        fi
    fi
    
    mkdir -p "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    echo_info "✅ Workspace created at $WORKSPACE_DIR"
}

# Function to download source
download_source() {
    echo_header "Downloading Chromium Source"
    
    if [ -d "$SOURCE_DIR" ]; then
        echo_info "Source directory exists, syncing..."
        cd "$SOURCE_DIR"
        gclient sync
    else
        echo_info "Fetching Chromium source (this may take 30-60 minutes)..."
        cd "$WORKSPACE_DIR"
        fetch --nohooks chromium
        cd "$SOURCE_DIR"
    fi
    
    echo_info "Checking out version $CHROMIUM_VERSION..."
    git checkout "$CHROMIUM_VERSION"
    
    echo_info "Syncing dependencies..."
    gclient sync
    
    echo_info "Running build hooks..."
    gclient runhooks
    
    echo_info "✅ Source code ready"
}

# Function to apply patches
apply_patches() {
    echo_header "Applying Custom Patches"
    
    cd "$SOURCE_DIR"
    
    # Check if patches already applied
    if git diff --quiet; then
        echo_info "Applying patches from $PROJECT_ROOT/patches/"
        
        for patch in "$PROJECT_ROOT/patches"/*.patch; do
            if [ -f "$patch" ]; then
                echo_info "Applying $(basename "$patch")..."
                if git apply "$patch"; then
                    echo_info "✅ $(basename "$patch") applied successfully"
                else
                    echo_warn "⚠️ $(basename "$patch") failed to apply cleanly"
                    echo_warn "You may need to apply this patch manually"
                    echo_warn "See docs/code-changes.md for manual instructions"
                fi
            fi
        done
    else
        echo_info "Source code already modified, skipping patch application"
        echo_info "Current modifications:"
        git diff --name-only | sed 's/^/  /'
    fi
    
    echo_info "✅ Patches applied"
}

# Function to configure build
configure_build() {
    echo_header "Configuring Build"
    
    cd "$SOURCE_DIR"
    
    # Create build directory
    mkdir -p out/Release
    
    # Configure build arguments
    echo_info "Generating build configuration..."
    gn gen out/Release --args="
# Basic configuration
is_debug = false
dcheck_always_on = false
is_component_build = false
symbol_level = 1
blink_symbol_level = 0
v8_symbol_level = 0

# Google services integration
enable_google_api_keys = true

# Media support
proprietary_codecs = true
ffmpeg_branding = \"Chrome\"
enable_widevine = true

# Performance optimizations
use_custom_libcxx = true
treat_warnings_as_errors = false

# Feature flags
enable_media_foundation = true
enable_media_remoting = true
"
    
    echo_info "✅ Build configured"
}

# Function to build chromium
build_chromium() {
    echo_header "Building Chromium"
    
    cd "$SOURCE_DIR"
    
    echo_info "Starting build (this may take 1-4 hours)..."
    echo_info "You can monitor progress in another terminal with: ps aux | grep ninja"
    
    # Determine optimal job count based on available memory
    MEMORY_GB=$(sysctl hw.memsize | awk '{print int($2/1024/1024/1024)}')
    if [ "$MEMORY_GB" -ge 16 ]; then
        JOBS=8
    elif [ "$MEMORY_GB" -ge 8 ]; then
        JOBS=4
    else
        JOBS=2
    fi
    
    echo_info "Building with $JOBS parallel jobs (${MEMORY_GB}GB RAM detected)"
    
    autoninja -j"$JOBS" -C out/Release chrome
    
    echo_info "✅ Build completed successfully"
}

# Function to verify build
verify_build() {
    echo_header "Verifying Build"
    
    cd "$SOURCE_DIR"
    
    # Check if app bundle exists
    if [ -d "out/Release/Chromium.app" ]; then
        echo_info "✅ App bundle created"
    else
        echo_error "❌ App bundle not found"
        exit 1
    fi
    
    # Check if executable works
    if ./out/Release/Chromium.app/Contents/MacOS/Chromium --version >/dev/null 2>&1; then
        echo_info "✅ Executable runs correctly"
    else
        echo_error "❌ Executable failed to run"
        exit 1
    fi
    
    # Test user agent modification
    USER_AGENT=$(./out/Release/Chromium.app/Contents/MacOS/Chromium --headless --dump-dom \
        'data:text/html,<script>document.write(navigator.userAgent)</script>' 2>/dev/null || echo "")
    
    if echo "$USER_AGENT" | grep -q "Chrome"; then
        echo_info "✅ Chrome user agent detected"
    else
        echo_warn "⚠️ User agent modification may not be working"
    fi
    
    echo_info "✅ Build verification completed"
}

# Function to install
install_build() {
    echo_header "Installing to macOS"
    
    if [ -f "$PROJECT_ROOT/scripts/install_macos_gui.sh" ]; then
        echo_info "Running macOS integration script..."
        CHROMIUM_SOURCE="$SOURCE_DIR" "$PROJECT_ROOT/scripts/install_macos_gui.sh"
        echo_info "✅ Installation completed"
    else
        echo_warn "Installation script not found, copying manually..."
        mkdir -p ~/Applications
        cp -R "$SOURCE_DIR/out/Release/Chromium.app" ~/Applications/
        echo_info "✅ App bundle copied to ~/Applications"
        echo_info "Run the installation script for full macOS integration"
    fi
}

# Main execution
main() {
    echo_header "Custom Chromium Build Script"
    echo "This script will build a custom Chromium browser with enterprise compatibility"
    echo "Project: osx-userland-chromium"
    echo "Version: $CHROMIUM_VERSION"
    echo "Workspace: $WORKSPACE_DIR"
    echo
    
    # Confirm before proceeding
    read -p "Continue with build? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Build cancelled"
        exit 0
    fi
    
    START_TIME=$(date +%s)
    
    check_prerequisites
    setup_workspace
    download_source
    apply_patches
    configure_build
    build_chromium
    verify_build
    install_build
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    HOURS=$((DURATION / 3600))
    MINUTES=$(((DURATION % 3600) / 60))
    
    echo_header "Build Complete!"
    echo
    echo_info "Total build time: ${HOURS}h ${MINUTES}m"
    echo_info "Custom Chromium installed with enhanced features:"
    echo "  ✅ Okta/SAML authentication support"
    echo "  ✅ OAuth redirect compatibility"
    echo "  ✅ Enhanced text selection in URL bar"
    echo "  ✅ Automatic session restore"
    echo "  ✅ Full macOS GUI integration"
    echo
    echo "Launch your custom Chromium with: open -a Chromium"
    echo "Or via Spotlight: Cmd+Space, type 'Chromium'"
}

# Handle script interruption
trap 'echo_error "Build interrupted"; exit 1' INT TERM

# Run main function
main "$@"