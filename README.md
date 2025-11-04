# macOS Userland Chromium

A comprehensive guide to building and customizing Chromium on macOS with enterprise compatibility fixes.

## Overview

This repository documents the process of building a custom Chromium browser on macOS with specific fixes for:
- 🖱️ **Enhanced Text Selection** - Focus-independent double-click word selection in the omnibox
- 🔄 **Session Management** - Automatic session restoration and improved startup behavior  

The word selection patch restores the expected behavior of word selection by double-clicking in the URL bar. It was clobbered in a recent Chrome update; the last known good binary package is 139.0.7258.128, but the Chromium source with this same tag already contains the bug.

Session restoration has always been a problem in Apple's Chromium builds. This patch changes the default startup behavior to always restore the last session.

An attendant problem is that Chromium source is not configured the same way as Google's Chrome builds. The default configuration lacks support for enterprise features like OAuth redirects (Okta, SAML) due to private network access restrictions, and the user agent string identifies the browser as "Chromium," which some services block. This build configures proprietary codecs, Google API keys, and modifies the user agent to report as Chrome.

- 🔐 **Okta/SAML Authentication** - OAuth redirect support with private network access bypass
- 🛡️ **Enterprise Compatibility** - User agent branding and network security bypasses
- 🍎 **macOS Integration** - Proper GUI integration with Spotlight, Dock, and Applications folder

## Features

### ✅ Resolved Issues
- **Okta Push Notifications**: Works via Chrome user agent branding
- **OAuth Redirects**: Complete redirect flow with private network access bypass
- **Double-Click Selection**: Focus-independent word selection in URL bar
- **Triple-Click Selection**: Standard macOS triple-click behavior (select all) in URL bar
- **Session Restore**: Automatic restoration of previous browsing session
- **Private Network Access**: Source-level bypass for enterprise compatibility
- **API Key Warnings**: Eliminated Google API key missing warnings
- **Camera/Media Support**: Full media device access enabled
- **macOS GUI Integration**: Proper app bundle with Chromium icon and naming
- **Tab Search URL Matching**: Tab search menu (Command-Shift-A) matches and highlights full tab URLs, not just tab titles or hostnames. See `patches/tab-search-url.patch`.

### 🔧 Technical Improvements
- **User Agent**: Modified to report as Chrome for web compatibility
- **Network Security**: Relaxed for OAuth/SAML authentication flows
- **Text Selection**: Restored double-click (word) and triple-click (all) behavior in omnibox
- **Build Optimization**: Configured for compatibility and performance

## Prerequisites

### System Requirements
- macOS 10.15 (Catalina) or later
- Xcode Command Line Tools
- At least 8GB RAM (16GB+ recommended)
- 200GB+ free disk space (the source alone is ~60GB)

### Required Tools
- Git
- Python 3
- depot_tools (Chromium build system)


## Quick Start

### 1. Setup Build Environment
```bash
# Install depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/src/depot_tools
export PATH="$HOME/src/depot_tools:$PATH"

# Create workspace
mkdir ~/chromium && cd ~/chromium
```

### 2. Download Source
```bash
# Fetch Chromium source (this takes time and bandwidth)
fetch --nohooks chromium
cd src

# Sync to specific stable version
git checkout 139.0.7258.128
gclient sync
```

### 3. Apply Custom Patches
```bash
# Clone this repo
git clone https://github.com/selkovjr/osx-userland-chromium.git ~/patches

# Apply patches (see patches/ directory)
cd ~/chromium/src
git apply ~/patches/patches/*.patch
```

### 4. Build Configuration
```bash
# Generate build files
gn gen out/Release --args='
enable_google_api_keys = true
proprietary_codecs = true  
ffmpeg_branding = "Chrome"
is_debug = false
dcheck_always_on = false
is_component_build = false
symbol_level = 1
blink_symbol_level = 0
v8_symbol_level = 0
'
```

### 5. Build Chromium
```bash
# Build (this took more than 20 hours on my M3 MackBook Pro with 18 GB of memory, with full CPU utilization)
ulimit -n 65536 && export PATH="$HOME/src/depot_tools:$PATH" && cd /Users/gene.selkov/chromium/src && autoninja -C out/Release chrome
```

### 6. Install for macOS GUI Integration
```bash
# Run our installation script
./install_macos_gui.sh
```

## Detailed Documentation

- [📋 **Complete Build Guide**](docs/build-guide.md) - Step-by-step build instructions
- [🔧 **Source Code Changes**](docs/code-changes.md) - Detailed technical modifications
- [🍎 **macOS Integration**](docs/macos-integration.md) - GUI setup and configuration
- [🔐 **Enterprise Features**](docs/enterprise-features.md) - Authentication and security bypasses
- [🛠️ **Troubleshooting**](docs/troubleshooting.md) - Common issues and solutions

## File Structure

```
osx-userland-chromium/
├── README.md                 # This file
├── docs/                     # Detailed documentation
│   ├── build-guide.md        # Complete build instructions
│   ├── code-changes.md       # Technical modifications
│   ├── macos-integration.md  # GUI integration
│   ├── enterprise-features.md # Authentication fixes
│   └── troubleshooting.md    # Problem solving
├── patches/                  # Source code patches
│   ├── user-agent.patch      # Chrome branding fix
│   ├── private-network.patch # Network access bypass
│   ├── double-click.patch    # Text selection enhancement
│   ├── triple-click.patch    # Triple-click select all
│   ├── session-restore.patch # Startup behavior
│   └── tab-search-url.patch  # Tab search URL matching
├── scripts/                  # Helper scripts
│   ├── install_macos_gui.sh  # macOS GUI integration
│   ├── build.sh             # Automated build script
│   ├── restore_session.sh   # Session management
│   └── test_features.sh     # Feature testing
└── config/                   # Build configurations
    ├── args.gn              # Build arguments
    └── .gclient             # Sync configuration
```

## Key Modifications

### 1. User Agent Branding (`components/embedder_support/user_agent_utils.cc`)
Forces Chrome branding for web compatibility:
```cpp
#if !BUILDFLAG(CHROMIUM_BRANDING)
  brand = version_info::GetProductName();
#else
  // Force Chrome branding for better web compatibility (Okta, etc.)
  brand = std::nullopt;  // This makes it use Chrome branding
#endif
```

### 2. Private Network Access Bypass (`services/network/private_network_access_url_loader_interceptor.cc`)
Disables private network blocking for OAuth:
```cpp
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(...) {
  // MODIFIED: Always allow private network access for OAuth/SAML compatibility
  return net::OK;
  // ... (original blocking code commented out)
}
```

### 3. Enhanced Double-Click Selection (`chrome/browser/ui/views/omnibox/omnibox_view_views.*`)
Custom mouse event handling for focus-independent word selection:
- Override `OnMouseEvent()` for unfocused double-click detection
- Override `OnMousePressed()` for focused double-click handling  
- Override `OnFocus()` for double-click after focus acquisition

### 4. Session Restore Default (`chrome/browser/prefs/session_startup_pref.cc`)
Changes default startup behavior:
```cpp
SessionStartupPref::Type SessionStartupPref::GetDefaultStartupType() {
#if BUILDFLAG(IS_CHROMEOS)
  return SessionStartupPref::DEFAULT;
#else
  return SessionStartupPref::LAST;  // Always restore last session
#endif
}
```

### 5. Tab Search URL Matching (`chrome/browser/ui/views/tabs/tab_search_view.cc`)
Enhances tab search functionality:
```cpp
void TabSearchView::OnTabSearch(...) {
  // MODIFIED: Match and highlight full tab URLs in addition to titles
  ...
  // Update search logic to include URL matching
  ...
}
```

## Installation & Usage

After building, use our macOS integration:

```bash
# Install to ~/Applications with proper GUI integration
./scripts/install_macos_gui.sh

# Launch via Spotlight (search "Chromium")
# Or via terminal:
open -a "Chromium"
```

## Testing Features

```bash
# Test all custom features
./scripts/test_features.sh

# Test specific components
open test_user_agent.html      # Verify Chrome user agent
# Try Okta authentication       # Test OAuth redirects  
# Double-click URL bar text     # Test text selection
# Open tab search (Command-Shift-A) # Test tab search URL matching
```

## Version Compatibility

- **Chromium Version**: 139.0.7258.128 (tested)
- **macOS**: 10.15+ (Catalina and later)
- **Xcode**: 12.0+ Command Line Tools

For other Chromium versions, patches may need adjustment.

## License

This project follows Chromium's BSD-style license. See individual files for specific licensing information.

## Acknowledgments

- Developed in Github Copilot / VSCode environment by Claude Sonnet 4.5 and ChatGPT-4.1. I have not touched a single line of Chromium code.

---

**Status**: ✅ Production ready - All features tested and working