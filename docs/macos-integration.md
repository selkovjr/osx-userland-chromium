# macOS Integration Guide

This guide covers integrating your custom Chromium build with macOS GUI systems including Dock, Spotlight, Applications folder, and LaunchServices.

## Overview

macOS provides several integration points for applications:
- **App Bundles**: Native application packaging format
- **LaunchServices**: Application registration and file associations  
- **Spotlight**: Search integration and metadata indexing
- **Dock**: Application launching and window management
- **Applications Folder**: Standard installation location

## App Bundle Structure

### Standard Chromium App Bundle

After building, Chromium creates an app bundle at:
```
out/Release/Chromium.app/
├── Contents/
│   ├── Info.plist              # App metadata and configuration
│   ├── MacOS/
│   │   └── Chromium           # Main executable binary
│   ├── Resources/
│   │   ├── app.icns           # Application icon
│   │   ├── document.icns      # Document icon
│   │   └── [other resources]
│   ├── Frameworks/            # Embedded frameworks
│   └── Helpers/               # Helper applications
```

### Customizing App Bundle Identity

#### 1. Update Info.plist

Edit `out/Release/Chromium.app/Contents/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Application Identity -->
    <key>CFBundleName</key>
    <string>Chromium</string>
    
    <key>CFBundleDisplayName</key>
    <string>Chromium</string>
    
    <key>CFBundleIdentifier</key>
    <string>org.chromium.Chromium</string>
    
    <key>CFBundleVersion</key>
    <string>139.0.7258.128</string>
    
    <key>CFBundleShortVersionString</key>
    <string>139.0.7258.128</string>
    
    <!-- Executable Information -->
    <key>CFBundleExecutable</key>
    <string>Chromium</string>
    
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    
    <!-- Icons -->
    <key>CFBundleIconFile</key>
    <string>app.icns</string>
    
    <!-- URL Schemes (for web browser functionality) -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>Web site URL</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>http</string>
                <string>https</string>
            </array>
        </dict>
    </array>
    
    <!-- File Type Associations -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>HTML Document</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>html</string>
                <string>htm</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
        </dict>
    </array>
    
    <!-- High Resolution Support -->
    <key>NSHighResolutionCapable</key>
    <true/>
    
    <!-- Security Settings -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
```

#### 2. Custom Application Icon

Replace the default Chromium icon with a custom one:

```bash
# Create custom icon (requires existing PNG or other image)
# Use iconutil to convert from iconset to icns

# Create iconset directory
mkdir Chromium.iconset

# Add icon files at various resolutions
cp icon_16x16.png Chromium.iconset/icon_16x16.png
cp icon_32x32.png Chromium.iconset/icon_16x16@2x.png
cp icon_32x32.png Chromium.iconset/icon_32x32.png
cp icon_64x64.png Chromium.iconset/icon_32x32@2x.png
cp icon_128x128.png Chromium.iconset/icon_128x128.png
cp icon_256x256.png Chromium.iconset/icon_128x128@2x.png
cp icon_256x256.png Chromium.iconset/icon_256x256.png
cp icon_512x512.png Chromium.iconset/icon_256x256@2x.png
cp icon_512x512.png Chromium.iconset/icon_512x512.png
cp icon_1024x1024.png Chromium.iconset/icon_512x512@2x.png

# Convert to icns format
iconutil -c icns Chromium.iconset

# Replace in app bundle
cp Chromium.icns out/Release/Chromium.app/Contents/Resources/app.icns
```

## Installation Scripts

### 1. Basic Installation Script

Create `scripts/install_macos_gui.sh`:

```bash
#!/bin/bash

# macOS GUI Integration Script for Custom Chromium
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROMIUM_SOURCE="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$CHROMIUM_SOURCE/out/Release"
APP_BUNDLE="$BUILD_DIR/Chromium.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo_error "Chromium app bundle not found at $APP_BUNDLE"
    echo_error "Please build Chromium first with: autoninja -C out/Release chrome"
    exit 1
fi

echo_info "Installing Custom Chromium to macOS GUI..."

# 1. Create ~/Applications directory if it doesn't exist
mkdir -p ~/Applications

# 2. Copy app bundle to user Applications
echo_info "Copying app bundle to ~/Applications..."
if [ -d ~/Applications/Chromium.app ]; then
    echo_warn "Removing existing Chromium.app..."
    rm -rf ~/Applications/Chromium.app
fi

cp -R "$APP_BUNDLE" ~/Applications/

# 3. Update permissions
echo_info "Setting executable permissions..."
chmod +x ~/Applications/Chromium.app/Contents/MacOS/Chromium

# 4. Register with LaunchServices
echo_info "Registering with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f ~/Applications/Chromium.app

# 5. Update Spotlight index
echo_info "Updating Spotlight index..."
mdimport ~/Applications/Chromium.app

# 6. Create command-line launcher
echo_info "Creating command-line launcher..."
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/chromium > /dev/null << 'EOF'
#!/bin/bash
# Custom Chromium Launcher
exec ~/Applications/Chromium.app/Contents/MacOS/Chromium "$@"
EOF

sudo chmod +x /usr/local/bin/chromium

# 7. Verify installation
echo_info "Verifying installation..."

if [ -d ~/Applications/Chromium.app ]; then
    echo_info "✅ App bundle installed to ~/Applications/Chromium.app"
else
    echo_error "❌ App bundle installation failed"
    exit 1
fi

if [ -x /usr/local/bin/chromium ]; then
    echo_info "✅ Command-line launcher installed to /usr/local/bin/chromium"
else
    echo_warn "⚠️ Command-line launcher installation failed (may need sudo)"
fi

# Test LaunchServices registration
if /usr/bin/mdfind "kMDItemCFBundleIdentifier == 'org.chromium.Chromium'" | grep -q Chromium.app; then
    echo_info "✅ LaunchServices registration successful"
else
    echo_warn "⚠️ LaunchServices registration may not be complete"
fi

echo_info "Installation complete!"
echo
echo "You can now:"
echo "  • Launch via Spotlight: Press Cmd+Space, type 'Chromium'"
echo "  • Launch via Dock: Drag ~/Applications/Chromium.app to Dock"
echo "  • Launch via Terminal: Run 'chromium' or 'open -a Chromium'"
echo "  • Launch via Finder: Open ~/Applications and double-click Chromium"
echo
echo "To uninstall:"
echo "  • Remove ~/Applications/Chromium.app"
echo "  • Remove /usr/local/bin/chromium"
echo "  • Run: lsregister -u ~/Applications/Chromium.app"

```

### 2. Advanced Installation with Preferences

Create `scripts/install_with_preferences.sh`:

```bash
#!/bin/bash

# Advanced macOS Installation with Custom Preferences
set -e

# ... (include basic installation code from above)

# Configure default preferences
echo_info "Configuring default preferences..."

PREFS_DIR=~/Library/Application\ Support/Chromium/Default
mkdir -p "$PREFS_DIR"

# Create custom preferences file
cat > "$PREFS_DIR/Preferences" << 'EOF'
{
   "session": {
      "restore_on_startup": 1
   },
   "browser": {
      "show_home_button": true,
      "check_default_browser": false
   },
   "bookmark_bar": {
      "show_on_all_tabs": true
   },
   "net": {
      "network_prediction_options": 2
   },
   "profile": {
      "default_content_setting_values": {
         "notifications": 1
      }
   }
}
EOF

echo_info "✅ Default preferences configured"
```

## LaunchServices Integration

### 1. Manual Registration

```bash
# Register app with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f ~/Applications/Chromium.app

# Verify registration
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -dump | grep -i chromium

# Check bundle ID registration
mdfind "kMDItemCFBundleIdentifier == 'org.chromium.Chromium'"
```

### 2. Set as Default Browser (Optional)

```bash
# List available browsers
/usr/bin/python3 -c "
from LaunchServices import LSCopyAllRoleHandlersForContentType
import CoreFoundation as CF
handlers = LSCopyAllRoleHandlersForContentType('public.html', CF.kLSRolesViewer)
print([str(h) for h in handlers])
"

# Set Chromium as default (requires user confirmation)
open "x-apple.systempreferences:com.apple.preference.security?General"
```

## Spotlight Integration

### 1. Update Metadata

```bash
# Force Spotlight to reindex the app
mdimport ~/Applications/Chromium.app

# Check indexed metadata
mdls ~/Applications/Chromium.app

# Verify Spotlight can find it
mdfind "Chromium"
mdfind "kMDItemCFBundleIdentifier == 'org.chromium.Chromium'"
```

### 2. Enhanced Metadata (Optional)

Add to `Info.plist`:

```xml
<!-- Enhanced Spotlight metadata -->
<key>MDItemKeywords</key>
<array>
    <string>browser</string>
    <string>web</string>
    <string>internet</string>
    <string>chrome</string>
    <string>chromium</string>
</array>

<key>MDItemDescription</key>
<string>Custom Chromium browser with enterprise compatibility</string>
```

## Dock Integration

### 1. Add to Dock Permanently

```bash
# Add to Dock using dockutil (install via Homebrew)
brew install dockutil

# Add Chromium to Dock
dockutil --add ~/Applications/Chromium.app --allhomes

# Or manually drag ~/Applications/Chromium.app to Dock
```

### 2. Custom Dock Badge/Icon

The Dock will automatically use the `app.icns` icon from the app bundle.

## File Associations

### 1. Associate with Web Files

Update `Info.plist` to handle web files:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>HTML Document</string>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>html</string>
            <string>htm</string>
            <string>xhtml</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>CFBundleTypeIconFile</key>
        <string>document.icns</string>
    </dict>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Web Archive</string>
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>webarchive</string>
        </array>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
    </dict>
</array>
```

### 2. URL Scheme Handling

Configure URL scheme handling in `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>Web URL</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>http</string>
            <string>https</string>
            <string>ftp</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>Chromium Custom Protocol</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>chromium</string>
        </array>
    </dict>
</array>
```

## Security and Notarization

### 1. Code Signing (for Distribution)

```bash
# Sign the app bundle (requires Apple Developer certificate)
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" \
    ~/Applications/Chromium.app

# Verify signature
codesign --verify --verbose ~/Applications/Chromium.app
spctl --assess --verbose ~/Applications/Chromium.app
```

### 2. Bypass Gatekeeper (Development Only)

```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine ~/Applications/Chromium.app

# Allow app to run without signing
sudo spctl --master-disable  # System-wide (not recommended)
# OR
spctl --add ~/Applications/Chromium.app  # App-specific
```

## Troubleshooting macOS Integration

### Common Issues

#### 1. "App is damaged and can't be opened"
```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine ~/Applications/Chromium.app

# Re-register with LaunchServices
lsregister -f ~/Applications/Chromium.app
```

#### 2. App doesn't appear in Spotlight
```bash
# Force reindexing
sudo mdutil -i on /
mdimport ~/Applications/Chromium.app

# Check if indexed
mdls ~/Applications/Chromium.app | grep kMDItemDisplayName
```

#### 3. Dock icon appears generic
```bash
# Verify icon file exists
ls -la ~/Applications/Chromium.app/Contents/Resources/app.icns

# Clear icon cache
sudo rm -rf /Library/Caches/com.apple.iconservices.store
sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \;
killall Dock
```

#### 4. Can't set as default browser
```bash
# Check bundle ID registration
lsregister -dump | grep -i chromium

# Verify URL scheme registration
defaults read LSHandlers | grep -A 5 -B 5 "org.chromium.Chromium"
```

### Reset Integration

If integration becomes corrupted:

```bash
# Complete reset script
#!/bin/bash

echo "Resetting Chromium macOS integration..."

# 1. Unregister from LaunchServices
lsregister -u ~/Applications/Chromium.app

# 2. Remove from Spotlight index
mdimport -d ~/Applications/Chromium.app

# 3. Clear Dock cache
killall Dock

# 4. Remove and reinstall
rm -rf ~/Applications/Chromium.app
# ... (reinstall using install script)

echo "Reset complete. Please reinstall."
```

## Integration Testing

### 1. Automated Test Script

Create `scripts/test_macos_integration.sh`:

```bash
#!/bin/bash

# Test macOS Integration
set -e

echo "Testing macOS Integration..."

# Test 1: App bundle exists
if [ -d ~/Applications/Chromium.app ]; then
    echo "✅ App bundle found"
else
    echo "❌ App bundle missing"
    exit 1
fi

# Test 2: Executable works
if ~/Applications/Chromium.app/Contents/MacOS/Chromium --version >/dev/null 2>&1; then
    echo "✅ Executable runs"
else
    echo "❌ Executable failed"
fi

# Test 3: LaunchServices registration
if mdfind "kMDItemCFBundleIdentifier == 'org.chromium.Chromium'" | grep -q Chromium.app; then
    echo "✅ LaunchServices registered"
else
    echo "❌ LaunchServices registration failed"
fi

# Test 4: Spotlight findable
if mdfind "Chromium" | grep -q Chromium.app; then
    echo "✅ Spotlight can find app"
else
    echo "❌ Spotlight cannot find app"
fi

# Test 5: Command line launcher
if which chromium >/dev/null 2>&1; then
    echo "✅ Command line launcher available"
else
    echo "⚠️ Command line launcher not available"
fi

echo "macOS integration testing complete!"
```

---

**Summary**: Following this guide will provide full macOS integration for your custom Chromium, making it behave like a native macOS application with proper GUI integration, file associations, and system service registration.