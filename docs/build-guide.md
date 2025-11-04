# Complete Build Guide

This guide provides step-by-step instructions for building a custom Chromium browser on macOS with enterprise compatibility fixes.

## Prerequisites Setup

### 1. Install Xcode Command Line Tools

```bash
# Check if already installed
xcode-select --print-path

# If not installed:
xcode-select --install
```

### 2. Install depot_tools

```bash
# Clone depot_tools (Chromium's build system)
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/src/depot_tools

# Add to PATH permanently
echo 'export PATH="$HOME/src/depot_tools:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
which gclient
which gn
```

### 3. Create Workspace Directory

```bash
# Create and navigate to build directory
mkdir -p ~/chromium
cd ~/chromium
```

## Source Code Acquisition

### 1. Fetch Chromium Source

```bash
# This downloads ~20GB and takes 30-60 minutes
fetch --nohooks chromium

# Navigate to source directory
cd src

# Check current version
git log --oneline -n 5
```

### 2. Sync to Stable Version

```bash
# Checkout specific stable version (tested)
git checkout 139.0.7258.128

# Sync dependencies (takes 15-30 minutes)
gclient sync

# Verify we're on the right version
git describe --tags
```

### 3. Install Build Dependencies

```bash
# Download additional build dependencies
gclient runhooks
```

## Apply Custom Patches

### 1. Clone Patches Repository

```bash
# Clone our patches repository
cd ~
git clone https://github.com/YOUR_USERNAME/osx-userland-chromium.git ~/patches

# Navigate back to Chromium source
cd ~/chromium/src
```

### 2. Apply Source Code Modifications

```bash
# Apply all patches at once
for patch in ~/patches/patches/*.patch; do
    echo "Applying $patch..."
    git apply "$patch"
done

# Or apply individually (recommended for omnibox-multiclick.patch):
git apply ~/patches/patches/user-agent.patch
git apply ~/patches/patches/private-network.patch
git apply ~/patches/patches/omnibox-multiclick.patch  # Combined double/triple-click
git apply ~/patches/patches/session-restore.patch
git apply ~/patches/patches/tab-search-url.patch

# Note: omnibox-multiclick.patch supersedes older double-click.patch and triple-click.patch

# Verify patches applied successfully
git status
git diff --name-only
```

### 3. Manual Modifications (if patches fail)

If patches don't apply cleanly, apply changes manually:

#### User Agent Modification
Edit `components/embedder_support/user_agent_utils.cc`:

```cpp
// Around line 200, in BuildOSCpuInfoFromOSVersionAndCpuType()
std::string brand;
#if !BUILDFLAG(CHROMIUM_BRANDING)
  brand = version_info::GetProductName();
#else
  // Force Chrome branding for better web compatibility (Okta, etc.)
  brand = std::nullopt;  // This makes it use Chrome branding
#endif
```

#### Private Network Access Bypass  
Edit `services/network/private_network_access_url_loader_interceptor.cc`:

```cpp
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(
    network::mojom::URLRequest* request,
    network::mojom::URLResponseHead* response_head,
    mojo::ScopedDataPipeConsumerHandle* response_body,
    const std::string& mime_type,
    bool* defer_loading) {
  // MODIFIED: Always allow private network access for OAuth/SAML compatibility
  return net::OK;
  
  // Original blocking logic (commented out):
  /*
  if (IsPrivateNetworkRequest(*url_request_)) {
    return net::ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS;
  }
  return net::OK;
  */
}
```

#### Session Restore Default
Edit `chrome/browser/prefs/session_startup_pref.cc`:

```cpp
SessionStartupPref::Type SessionStartupPref::GetDefaultStartupType() {
#if BUILDFLAG(IS_CHROMEOS)
  return SessionStartupPref::DEFAULT;
#else
  // Always restore last session by default on all platforms
  return SessionStartupPref::LAST;
#endif
}
```

#### Double-Click Enhancement
Edit `chrome/browser/ui/views/omnibox/omnibox_view_views.h` (add to class):

```cpp
private:
  // Custom double-click detection
  base::TimeTicks last_click_time_;
  gfx::Point last_click_location_;
  bool pending_double_click_on_focus_ = false;
  static constexpr base::TimeDelta kDoubleClickInterval = base::Milliseconds(500);
  static constexpr int kDoubleClickDistance = 5;
  
  bool IsDoubleClick(const ui::MouseEvent& event);
  void HandleDoubleClickSelection(const ui::MouseEvent& event);
```

Edit `chrome/browser/ui/views/omnibox/omnibox_view_views.cc` (add methods):

```cpp
bool OmniboxViewViews::IsDoubleClick(const ui::MouseEvent& event) {
  base::TimeTicks current_time = base::TimeTicks::Now();
  base::TimeDelta time_delta = current_time - last_click_time_;
  
  if (time_delta <= kDoubleClickInterval) {
    gfx::Point current_location = event.location();
    int distance = std::abs(current_location.x() - last_click_location_.x()) + 
                   std::abs(current_location.y() - last_click_location_.y());
    
    if (distance <= kDoubleClickDistance) {
      return true;
    }
  }
  
  last_click_time_ = current_time;
  last_click_location_ = event.location();
  return false;
}

void OmniboxViewViews::HandleDoubleClickSelection(const ui::MouseEvent& event) {
  size_t pos = GetTextIndexOfPoint(event.location());
  if (pos != std::string::npos) {
    std::u16string text = GetText();
    size_t start = pos, end = pos;
    
    // Find word boundaries
    while (start > 0 && !std::isspace(text[start - 1]) && text[start - 1] != '/') {
      start--;
    }
    while (end < text.length() && !std::isspace(text[end]) && text[end] != '/') {
      end++;
    }
    
    if (start < end) {
      SelectRange(gfx::Range(start, end));
    }
  }
}

// Override OnMouseEvent for unfocused double-click
bool OmniboxViewViews::OnMouseEvent(const ui::MouseEvent& event) {
  if (event.type() == ui::EventType::kMousePressed && 
      event.IsLeftMouseButton() && !HasFocus()) {
    if (IsDoubleClick(event)) {
      pending_double_click_on_focus_ = true;
      RequestFocus();
      return true;
    }
  }
  return false;
}

// Override OnMousePressed for focused double-click
bool OmniboxViewViews::OnMousePressed(const ui::MouseEvent& event) {
  if (event.IsLeftMouseButton() && HasFocus() && IsDoubleClick(event)) {
    HandleDoubleClickSelection(event);
    return true;
  }
  return Textfield::OnMousePressed(event);
}

// Override OnFocus to handle pending double-click
void OmniboxViewViews::OnFocus() {
  Textfield::OnFocus();
  
  if (pending_double_click_on_focus_) {
    pending_double_click_on_focus_ = false;
    
    // Select word at last click position
    size_t pos = GetTextIndexOfPoint(last_click_location_);
    if (pos != std::string::npos) {
      std::u16string text = GetText();
      size_t start = pos, end = pos;
      
      while (start > 0 && !std::isspace(text[start - 1]) && text[start - 1] != '/') {
        start--;
      }
      while (end < text.length() && !std::isspace(text[end]) && text[end] != '/') {
        end++;
      }
      
      if (start < end) {
        SelectRange(gfx::Range(start, end));
      }
    }
  }
}
```

### 4. Tab Search URL Matching
The tab search menu (Command-Shift-A) now matches and highlights full tab URLs, not just tab titles or hostnames. This is enabled by the `tab-search-url.patch`.

**How to apply:**
```bash
git apply ~/patches/patches/tab-search-url.patch
```

**Test:**
- Open the tab search menu and search for any part of a tab's URL. Matching tabs will be highlighted.

### 5. Omnibox Multi-Click Selection
The omnibox (URL bar) now supports standard macOS multi-click behavior:
- **Double-click**: Select word at cursor
- **Triple-click**: Select all text

This is enabled by the `omnibox-multiclick.patch` which supersedes the older `double-click.patch` and `triple-click.patch`.

**How to apply:**
```bash
git apply ~/patches/patches/omnibox-multiclick.patch
```

**Test:**
- Triple-click anywhere in the omnibox to select all text
- Double-click to select a word
- Single-click to position the caret

## Build Configuration

### 1. Generate Build Files

```bash
# Navigate to source directory
cd ~/chromium/src

# Generate build configuration (this sets up the build)
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
use_custom_libcxx = true
treat_warnings_as_errors = false
'
```

### 2. Configure Google API Keys (Optional)

For full Google services integration:

```bash
# Set environment variables for Google API keys
# (Get these from Google Cloud Console)
export GOOGLE_API_KEY="your_api_key_here"
export GOOGLE_DEFAULT_CLIENT_ID="your_client_id_here"  
export GOOGLE_DEFAULT_CLIENT_SECRET="your_client_secret_here"

# Add to your shell profile for persistence
echo 'export GOOGLE_API_KEY="your_api_key_here"' >> ~/.zshrc
echo 'export GOOGLE_DEFAULT_CLIENT_ID="your_client_id_here"' >> ~/.zshrc
echo 'export GOOGLE_DEFAULT_CLIENT_SECRET="your_client_secret_here"' >> ~/.zshrc
```

### 3. Verify Build Configuration

```bash
# Check generated build files
gn desc out/Release :chrome

# Verify our custom arguments
gn args out/Release --list | grep -E "(google_api|proprietary_codecs|ffmpeg)"
```

## Building Chromium

### 1. Start Build Process

```bash
# Build Chromium (this takes 1-4 hours depending on your machine)
autoninja -C out/Release chrome

# Monitor build progress
# You can use another terminal to check:
# ps aux | grep ninja
# top -p $(pgrep ninja)
```

### 2. Build Optimization Tips

```bash
# Use more build jobs if you have RAM (16GB+ recommended)
autoninja -j 8 -C out/Release chrome

# Or limit jobs if you're running low on memory
autoninja -j 2 -C out/Release chrome

# Build specific targets if needed
autoninja -C out/Release chrome chrome_sandbox
```

### 3. Verify Build Success

```bash
# Check if binary was created
ls -la out/Release/Chromium.app/Contents/MacOS/Chromium

# Test basic functionality
./out/Release/Chromium.app/Contents/MacOS/Chromium --version

# Quick smoke test
./out/Release/Chromium.app/Contents/MacOS/Chromium --headless --dump-dom https://www.google.com
```

## Post-Build Setup

### 1. Test Custom Features

```bash
# Test user agent (should report as Chrome)
./out/Release/Chromium.app/Contents/MacOS/Chromium --user-data-dir=/tmp/test --headless --dump-dom data:text/html,"<script>document.write(navigator.userAgent)</script>"

# Test session restore (check preferences)
grep -r "session_startup" out/Release/Chromium.app/
```

### 2. Create App Bundle for Distribution

```bash
# Copy app bundle to Applications-style location
cp -R out/Release/Chromium.app ~/Applications/

# Or create a proper installer package
# (see macOS integration guide)
```

## Troubleshooting Build Issues

### Common Build Errors

#### 1. "No space left on device"
```bash
# Check disk space
df -h

# Clean build directory
gn clean out/Release
```

#### 2. "Python not found"
```bash
# Ensure Python 3 is available
python3 --version

# Update depot_tools
cd ~/src/depot_tools
git pull
```

#### 3. "Xcode tools outdated"
```bash
# Update Xcode command line tools
sudo xcode-select --install
```

#### 4. Patch Application Failures
```bash
# Check which patches failed
git status
git diff

# Apply patches individually
git apply ~/patches/patches/user-agent.patch
git apply ~/patches/patches/private-network.patch
git apply ~/patches/patches/omnibox-multiclick.patch  # Combined double/triple-click
git apply ~/patches/patches/session-restore.patch
git apply ~/patches/patches/tab-search-url.patch

# Note: omnibox-multiclick.patch supersedes older double-click.patch and triple-click.patch

# Or apply manually using the code snippets above
```

### Performance Tips

#### 1. Speed Up Builds
```bash
# Use ccache for faster rebuilds
brew install ccache
export CCACHE_DIR=~/.ccache
export CC="ccache clang"
export CXX="ccache clang++"
```

#### 2. Reduce Build Size
```bash
# Build with minimal symbols
gn gen out/Release --args='
symbol_level = 0
blink_symbol_level = 0
v8_symbol_level = 0
remove_webcore_debug_symbols = true
'
```

#### 3. Parallel Testing
```bash
# Run tests in parallel
autoninja -C out/Release unit_tests
./out/Release/unit_tests --gtest_shuffle
```

## Next Steps

After successful build:

1. **macOS Integration**: See [macOS Integration Guide](macos-integration.md)
2. **Feature Testing**: See [Enterprise Features Guide](enterprise-features.md)  
3. **Troubleshooting**: See [Troubleshooting Guide](troubleshooting.md)

## Build Time Estimates

| Hardware | Build Time | Notes |
|----------|------------|-------|
| MacBook Air M1 | 45-90 min | Excellent performance |
| MacBook Pro Intel i7 | 2-3 hours | Good performance |
| Mac Mini Intel i5 | 3-4 hours | Adequate performance |
| iMac Intel i5 | 2-4 hours | Depends on year/model |

**Memory Requirements**: 8GB minimum, 16GB+ recommended for parallel builds.

---

**Success**: After following this guide, you should have a fully functional custom Chromium with enterprise compatibility features ready for macOS integration.