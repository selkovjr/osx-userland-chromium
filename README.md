# macOS Userland Chromium

A comprehensive guide to building and customizing Chromium on macOS with enterprise compatibility fixes.

## Overview

This repository documents the process of building a custom Chromium browser on macOS with specific fixes for:
- 🔐 **Okta/SAML Authentication** - Full OAuth redirect support with private network access bypass
- 🖱️ **Enhanced Text Selection** - Focus-independent double-click word selection in the omnibox
- 🔄 **Session Management** - Automatic session restoration and improved startup behavior  
- 🛡️ **Enterprise Compatibility** - User agent branding and network security bypasses
- 🍎 **macOS Integration** - Proper GUI integration with Spotlight, Dock, and Applications folder

## Features

### ✅ Resolved Issues
- **Okta Push Notifications**: Works via Chrome user agent branding
- **OAuth Redirects**: Complete redirect flow with private network access bypass
- **Double-Click Selection**: Focus-independent word selection in URL bar
- **Session Restore**: Automatic restoration of previous browsing session
- **Private Network Access**: Source-level bypass for enterprise compatibility
- **API Key Warnings**: Eliminated Google API key missing warnings
- **Camera/Media Support**: Full media device access enabled
- **macOS GUI Integration**: Proper app bundle with Chromium icon and naming

### 🔧 Technical Improvements
- **User Agent**: Modified to report as Chrome for web compatibility
- **Network Security**: Relaxed for OAuth/SAML authentication flows
- **Text Selection**: Custom mouse event handling for enhanced UX
- **Build Optimization**: Configured for compatibility and performance

## Prerequisites

### System Requirements
- macOS 10.15 (Catalina) or later
- Xcode Command Line Tools
- At least 8GB RAM (16GB+ recommended)
- 50GB+ free disk space

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
git clone https://github.com/YOUR_USERNAME/osx-userland-chromium.git ~/patches

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
# Build (this takes 1-4 hours depending on your machine)
autoninja -C out/Release chrome
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
│   └── session-restore.patch # Startup behavior
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
```

## Contributing

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/new-fix`
3. Document your changes in `docs/code-changes.md`
4. Create patches: `git format-patch -1 --stdout > patches/my-fix.patch`
5. Submit a pull request

## Version Compatibility

- **Chromium Version**: 139.0.7258.128 (tested)
- **macOS**: 10.15+ (Catalina and later)
- **Xcode**: 12.0+ Command Line Tools

For other Chromium versions, patches may need adjustment.

## License

This project follows Chromium's BSD-style license. See individual files for specific licensing information.

## Acknowledgments

- Chromium project for the excellent browser foundation
- Enterprise users who need OAuth/SAML compatibility
- macOS integration techniques from the community

---

**Status**: ✅ Production ready - All features tested and working

Built with ❤️ for macOS enterprise users who need Chrome compatibility without Chrome.