# Troubleshooting Guide

This guide covers common issues encountered when building and using the custom Chromium browser, along with their solutions.

## Build Issues

### 1. Build Environment Problems

#### "No such file or directory: depot_tools"

**Symptoms**:
```bash
bash: gclient: command not found
bash: gn: command not found
```

**Solution**:
```bash
# Verify depot_tools installation
which gclient
which gn

# If not found, install depot_tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/src/depot_tools

# Add to PATH
echo 'export PATH="$HOME/src/depot_tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### "Python not found" Errors

**Symptoms**:
```bash
/usr/bin/env: 'python': No such file or directory
```

**Solution**:
```bash
# Check Python installation
python3 --version

# Create python symlink if needed
sudo ln -sf /usr/bin/python3 /usr/local/bin/python

# Or set Python explicitly
export VPYTHON_BYPASS="manually managed python not supported by chrome operations"
```

#### "Xcode tools outdated"

**Symptoms**:
```bash
xcode-select: error: tool 'xcodebuild' requires Xcode
```

**Solution**:
```bash
# Update Xcode command line tools
sudo xcode-select --install

# Or if Xcode is installed but not selected
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 2. Source Code Issues

#### Git Checkout Failures

**Symptoms**:
```bash
error: pathspec '139.0.7258.128' did not match any file(s) known to git
```

**Solution**:
```bash
# Fetch all tags and branches
git fetch --all --tags

# List available tags
git tag | grep 139.0

# Try alternative version
git checkout 139.0.7258.127

# Or use latest stable
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))
```

#### Sync Failures

**Symptoms**:
```bash
Error: Command 'git -c core.deltaBaseCacheLimit=2g checkout' returned non-zero exit status 1
```

**Solution**:
```bash
# Clean and retry sync
gclient revert
gclient sync --force

# If still failing, delete and re-fetch
cd ~/chromium
rm -rf src
fetch --nohooks chromium
```

### 3. Patch Application Issues

#### Patch Doesn't Apply Cleanly

**Symptoms**:
```bash
error: patch failed: components/embedder_support/user_agent_utils.cc:205
error: components/embedder_support/user_agent_utils.cc: patch does not apply
```

**Solution**:
```bash
# Check what changed
git diff components/embedder_support/user_agent_utils.cc

# Apply patch with context
git apply --reject --whitespace=fix patches/user-agent.patch

# Manually resolve conflicts
# Edit files to apply changes manually
# See docs/code-changes.md for exact modifications
```

#### Patch Applied to Wrong Location

**Symptoms**:
- Code compiles but features don't work
- Changes not taking effect

**Solution**:
```bash
# Verify patches were applied
git diff --name-only

# Check specific files
git diff components/embedder_support/user_agent_utils.cc
git diff services/network/private_network_access_url_loader_interceptor.cc

# Re-apply manually if needed
```

### 4. Build Configuration Problems

#### GN Generation Failures

**Symptoms**:
```bash
ERROR at //build/config/compiler/BUILD.gn:123:1: Assignment had no effect.
```

**Solution**:
```bash
# Clean build directory
rm -rf out/Release

# Regenerate with verbose output
gn gen out/Release --args='...' --verbose

# Check for typos in args.gn
cat out/Release/args.gn
```

#### Missing Dependencies

**Symptoms**:
```bash
ERROR: dependency "//third_party/something" not found
```

**Solution**:
```bash
# Run hooks to download dependencies
gclient runhooks

# Force dependency sync
gclient sync --with_branch_heads --with_tags

# Check DEPS file for changes
git diff DEPS
```

### 5. Compilation Errors

#### Out of Disk Space

**Symptoms**:
```bash
FAILED: obj/something.o
No space left on device
```

**Solution**:
```bash
# Check available space
df -h

# Clean build artifacts
gn clean out/Release

# Use component build to reduce disk usage
gn gen out/Release --args='is_component_build=true'

# Or build on external drive
mkdir /Volumes/External/chromium_build
ln -s /Volumes/External/chromium_build out/Release
```

#### Memory Exhaustion

**Symptoms**:
```bash
c++: internal compiler error: Killed (program cc1plus)
```

**Solution**:
```bash
# Reduce parallel build jobs
autoninja -j2 -C out/Release chrome

# Or use more aggressive settings
gn gen out/Release --args='
symbol_level = 0
blink_symbol_level = 0  
v8_symbol_level = 0
'
```

#### Compiler Warnings as Errors

**Symptoms**:
```bash
error: unused variable 'something' [-Werror,-Wunused-variable]
```

**Solution**:
```bash
# Disable warnings as errors
gn gen out/Release --args='treat_warnings_as_errors=false'

# Or fix the specific warning
# Edit the file to remove unused variables
```

## Runtime Issues

### 1. Launch Problems

#### "App is damaged and can't be opened"

**Symptoms**:
- macOS Gatekeeper blocking unsigned app
- App won't launch from Finder

**Solution**:
```bash
# Remove quarantine attribute
xattr -dr com.apple.quarantine ~/Applications/Chromium.app

# Alternative: Right-click and select "Open"
# Or system preferences → Security & Privacy → Allow
```

#### Crash on Launch

**Symptoms**:
```bash
Segmentation fault: 11
```

**Solution**:
```bash
# Launch with debugging
~/Applications/Chromium.app/Contents/MacOS/Chromium --enable-logging --log-level=0

# Try safe mode
~/Applications/Chromium.app/Contents/MacOS/Chromium --no-sandbox --disable-gpu

# Check for conflicting software
# Disable antivirus/security software temporarily
```

#### Missing Libraries

**Symptoms**:
```bash
dyld: Library not loaded: @rpath/libsomething.dylib
```

**Solution**:
```bash
# Check library dependencies
otool -L ~/Applications/Chromium.app/Contents/MacOS/Chromium

# Verify build completed successfully
ls -la out/Release/Chromium.app/Contents/Frameworks/

# Rebuild if frameworks missing
autoninja -C out/Release chrome
```

### 2. Feature-Specific Issues

#### Okta Authentication Not Working

**Symptoms**:
- "Browser not supported" message
- Push notifications not received
- Authentication loops

**Diagnosis**:
```bash
# Check user agent
chromium --headless --dump-dom data:text/html,"<script>document.write(navigator.userAgent)</script>"

# Should output something like:
# Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.7258.128 Safari/537.36
```

**Solution**:
```bash
# Verify user agent patch applied
git diff components/embedder_support/user_agent_utils.cc

# If not applied, manually edit file:
# Change brand = version_info::GetProductName(); to brand = std::nullopt;

# Rebuild
autoninja -C out/Release chrome
```

#### OAuth Redirects Failing

**Symptoms**:
- `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS`
- OAuth flows timing out
- "Redirect not allowed" errors

**Diagnosis**:
```bash
# Test redirect manually
echo '<script>window.location.href="http://localhost:8080"</script>' > test_redirect.html
chromium test_redirect.html

# Should redirect without error
```

**Solution**:
```bash
# Verify private network bypass applied
git diff services/network/private_network_access_url_loader_interceptor.cc

# If not applied, edit OnConnected() function to return net::OK immediately

# Rebuild
autoninja -C out/Release chrome
```

#### Double-Click Selection Not Working

**Symptoms**:
- Double-clicking URL bar only focuses, doesn't select
- Word selection inconsistent

**Diagnosis**:
```bash
# Test in browser:
# 1. Navigate to any URL
# 2. Click elsewhere to unfocus URL bar
# 3. Double-click on word in URL bar
# 4. Should select the word
```

**Solution**:
```bash
# Verify omnibox patches applied
git diff chrome/browser/ui/views/omnibox/omnibox_view_views.*

# If not applied, manually add double-click detection code
# See docs/code-changes.md for complete implementation

# Rebuild
autoninja -C out/Release chrome
```

#### Session Restore Not Working

**Symptoms**:
- Browser starts with new tab instead of restoring session
- Previous tabs lost on restart

**Diagnosis**:
```bash
# Check preferences
cat "$HOME/Library/Application Support/Chromium/Default/Preferences" | grep restore_on_startup

# Should show: "restore_on_startup":1
```

**Solution**:
```bash
# Verify session restore patch applied
git diff chrome/browser/prefs/session_startup_pref.cc

# If not applied, change GetDefaultStartupType() to return SessionStartupPref::LAST

# Rebuild
autoninja -C out/Release chrome
```

### 3. Integration Issues

#### Spotlight Not Finding App

**Symptoms**:
- Cmd+Space doesn't find Chromium
- App not indexed by Spotlight

**Solution**:
```bash
# Force Spotlight reindex
sudo mdutil -i off / && sudo mdutil -i on /

# Reindex specific app
mdimport ~/Applications/Chromium.app

# Check if indexed
mdfind "Chromium"
```

#### LaunchServices Registration Failed

**Symptoms**:
- App doesn't appear in "Open With" menu
- Can't set as default browser

**Solution**:
```bash
# Re-register with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f ~/Applications/Chromium.app

# Reset LaunchServices database if corrupted
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Verify registration
lsregister -dump | grep -i chromium
```

#### Dock Icon Issues

**Symptoms**:
- Generic icon in Dock
- App name wrong in Dock

**Solution**:
```bash
# Clear icon cache
sudo rm -rf /Library/Caches/com.apple.iconservices.store
sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \;

# Restart Dock
killall Dock

# Verify icon file exists
ls -la ~/Applications/Chromium.app/Contents/Resources/app.icns
```

## Performance Issues

### 1. Slow Build Times

#### Disk I/O Bottleneck

**Solution**:
```bash
# Use SSD for build directory
# Move build to faster storage
mv out/Release /Volumes/FastSSD/chromium_build
ln -s /Volumes/FastSSD/chromium_build out/Release

# Use ccache for incremental builds
brew install ccache
export CC="ccache clang"
export CXX="ccache clang++"
```

#### CPU/Memory Optimization

**Solution**:
```bash
# Optimize build for your machine
# For 8GB RAM:
autoninja -j4 -C out/Release chrome

# For 16GB+ RAM:
autoninja -j8 -C out/Release chrome

# Monitor resource usage
top -o cpu | head -20
```

### 2. Runtime Performance

#### High Memory Usage

**Solution**:
```bash
# Launch with memory optimization
chromium --memory-pressure-off --max_old_space_size=512

# Disable unnecessary features
chromium --disable-background-timer-throttling --disable-renderer-backgrounding
```

#### GPU Issues

**Solution**:
```bash
# Disable GPU acceleration if problematic
chromium --disable-gpu --disable-software-rasterizer

# Or force specific GPU
chromium --use-gl=desktop
```

## Debugging Tools

### 1. Build Debugging

```bash
# Verbose build output
autoninja -v -C out/Release chrome

# Build specific target
autoninja -C out/Release components/embedder_support

# Show build commands
autoninja -C out/Release -t commands chrome
```

### 2. Runtime Debugging

```bash
# Enable all logging
chromium --enable-logging --log-level=0 --v=1

# Network debugging
chromium --log-net-log=/tmp/net_log.json

# JavaScript debugging
chromium --js-flags="--trace-gc --trace-opt"

# Crash debugging
chromium --enable-crash-reporter
```

### 3. Feature Testing

```bash
# Test user agent
chromium --user-data-dir=/tmp/test_profile --headless --dump-dom data:text/html,"<script>document.write(navigator.userAgent)</script>"

# Test private network access
python3 -m http.server 8080 &
chromium --user-data-dir=/tmp/test_profile "data:text/html,<script>fetch('http://localhost:8080').then(r=>console.log('Success')).catch(e=>console.log('Failed:', e))</script>"
```

## Common Error Messages

### Build Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `ninja: fatal: posix_spawn: Argument list too long` | Too many build targets | Use `is_component_build=true` |
| `fatal error: 'iostream' file not found` | Missing Xcode tools | `xcode-select --install` |
| `ERROR at //build/toolchain/mac/BUILD.gn` | Xcode version incompatible | Update Xcode |
| `No such file or directory: 'python'` | Python not found | Install Python 3 |

### Runtime Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS` | Private network bypass not applied | Apply private network patch |
| `Browser not supported` on Okta | Chromium user agent detected | Apply user agent patch |
| Crash on launch | Missing dependencies | Check build completion |
| `Cannot connect to X11` | Wrong platform build | Build for macOS target |

## Getting Help

### 1. Check Build Status

```bash
# Verify patches applied
git status
git diff --name-only

# Check build configuration
gn args out/Release --list | grep -E "(api_key|branding|symbol)"

# Test basic functionality
chromium --version
```

### 2. Collect Debug Information

```bash
# System information
system_profiler SPSoftwareDataType SPHardwareDataType

# Build information
git describe --tags
gn desc out/Release :chrome

# Runtime information
chromium --enable-logging --log-level=0 --v=1 > debug.log 2>&1
```

### 3. Clean Rebuild

When all else fails:

```bash
# Complete clean rebuild
cd ~/chromium/src
git clean -fdx
gclient revert
gclient sync
gn clean out/Release

# Re-apply patches
for patch in ~/patches/patches/*.patch; do
    git apply "$patch"
done

# Rebuild
gn gen out/Release --args='...'
autoninja -C out/Release chrome
```

---

**Summary**: Most issues can be resolved by verifying the build environment, ensuring patches are applied correctly, and rebuilding when necessary. When in doubt, start with a clean rebuild and systematic testing of each feature.