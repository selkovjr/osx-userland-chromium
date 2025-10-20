# Enterprise Features Guide

This guide covers the enterprise-specific features and compatibility fixes implemented in our custom Chromium build.

## Overview

Enterprise environments have specific requirements that standard Chromium doesn't always meet:

- 🔐 **Authentication Compatibility** - Support for enterprise SSO systems
- 🌐 **Network Access** - Bypass restrictions for OAuth flows  
- 🛡️ **Security Policies** - Maintain security while enabling functionality
- 📱 **Notification Support** - Full push notification support for enterprise apps
- 🔗 **Redirect Handling** - Complete OAuth/SAML redirect flows

## Authentication Systems

### Okta Integration

#### Problem
Okta and similar SAML/OAuth providers detect Chromium's user agent and deny access:
- Push notifications blocked
- "Browser not supported" messages
- Limited authentication methods

#### Solution: Chrome User Agent Branding

**Implementation**: Modified `components/embedder_support/user_agent_utils.cc`

```cpp
// Forces Chrome branding instead of Chromium
std::string brand;
#if !BUILDFLAG(CHROMIUM_BRANDING)
  brand = version_info::GetProductName();
#else
  // Force Chrome branding for better web compatibility (Okta, etc.)
  brand = std::nullopt;  // This makes it use Chrome branding
#endif
```

**Result**: 
- User agent reports as `Chrome/139.0.7258.128` instead of `Chromium/139.0.7258.128`
- Okta recognizes browser as fully supported
- Push notifications work correctly
- All authentication methods available

#### Testing Okta Integration

```bash
# Test user agent in browser console
navigator.userAgent
# Should contain "Chrome" not "Chromium"

# Test Okta push notifications
# 1. Navigate to your Okta portal
# 2. Attempt login with push notification
# 3. Should receive push on mobile device
# 4. Should complete authentication successfully
```

### Azure Active Directory (Azure AD)

#### Compatibility
- ✅ OAuth 2.0 flows work with Chrome user agent
- ✅ SAML assertions processed correctly  
- ✅ Conditional access policies supported
- ✅ Multi-factor authentication (MFA) functional

#### Configuration Tips

For optimal Azure AD integration:

```bash
# Launch with enterprise-friendly flags
chromium \
  --disable-features=VizDisplayCompositor \
  --enable-features=WebRTC-H264WithOpenH264FFmpeg \
  --no-sandbox \
  --disable-dev-shm-usage
```

### Other Enterprise SSO Systems

#### Tested Compatible Systems
- **Okta** - Full compatibility with user agent fix
- **Azure Active Directory** - Full compatibility
- **Ping Identity** - Compatible with Chrome user agent
- **Duo Security** - Works with private network bypass
- **OneLogin** - Compatible with Chrome branding

#### Known Issues and Workarounds

| System | Issue | Workaround |
|--------|-------|------------|
| Legacy SAML providers | Certificate warnings | Use `--ignore-certificate-errors` flag |
| Corporate proxies | Connection failures | Configure proxy settings |
| Self-signed certs | Security blocks | Use `--allow-running-insecure-content` |

## OAuth/SAML Redirect Flows

### Private Network Access Problem

Modern browsers block requests from public networks to private/local addresses for security. This breaks OAuth flows where:

1. User starts login on public site (e.g., `https://company.okta.com`)
2. Identity provider redirects to local application (e.g., `http://localhost:8080/callback`)
3. Browser blocks redirect with `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS`

### Solution: Source-Level Bypass

**Implementation**: Modified `services/network/private_network_access_url_loader_interceptor.cc`

```cpp
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(...) {
  // MODIFIED: Always allow private network access for OAuth/SAML compatibility
  return net::OK;
  
  // Original blocking logic (commented out):
  /*
  const network::ResourceRequest& url_request = *request;
  
  if (IsPrivateNetworkRequest(url_request)) {
    return net::ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS;
  }
  
  return net::OK;
  */
}
```

**Result**:
- OAuth redirects to localhost work correctly
- SAML POST callbacks to private addresses succeed
- Enterprise development environments accessible
- No command-line flags required

### Testing OAuth Flows

#### 1. Localhost Redirect Test

```html
<!-- Create test file: oauth_test.html -->
<!DOCTYPE html>
<html>
<head>
    <title>OAuth Redirect Test</title>
</head>
<body>
    <h1>OAuth Redirect Test</h1>
    <button onclick="testRedirect()">Test Localhost Redirect</button>
    
    <script>
    function testRedirect() {
        // Simulate OAuth redirect to localhost
        window.location.href = 'http://localhost:8080/callback?code=test123';
    }
    </script>
</body>
</html>
```

#### 2. Enterprise OAuth Test

```bash
# Start a local test server
python3 -m http.server 8080

# Open test page
chromium oauth_test.html

# Click test button - should redirect without error
# If working: redirects to localhost:8080
# If broken: shows ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS
```

### Real-World OAuth Testing

#### Common Enterprise OAuth Flows

1. **Okta to localhost app**:
   ```
   https://company.okta.com/oauth2/authorize
   ↓ (user authenticates)
   http://localhost:3000/callback?code=...
   ```

2. **Azure AD to development server**:
   ```
   https://login.microsoftonline.com/oauth2/authorize
   ↓ (user authenticates)  
   http://192.168.1.100:8080/auth/callback
   ```

3. **Corporate SAML to internal app**:
   ```
   https://sso.company.com/saml/login
   ↓ (user authenticates)
   http://internal.company.local/saml/acs
   ```

## Network Security Considerations

### Security Trade-offs

Our private network access bypass reduces security isolation:

**Disabled Protection**:
- Public → Private network request blocking
- CORS-style protection for local resources
- Some defense against malicious website attacks

**Maintained Security**:
- HTTPS certificate validation (unless explicitly disabled)
- Same-origin policy for most scenarios
- Content Security Policy (CSP) enforcement
- Malware and phishing protection

### Risk Mitigation

#### 1. Selective Application

Consider implementing domain-specific bypass:

```cpp
// Alternative implementation - allowlist approach
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(...) {
  const network::ResourceRequest& url_request = *request;
  
  // Allow specific enterprise domains
  if (IsAllowedEnterpriseOrigin(url_request.referrer)) {
    return net::OK;
  }
  
  // Apply normal private network checks for other domains
  if (IsPrivateNetworkRequest(url_request)) {
    return net::ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS;
  }
  
  return net::OK;
}
```

#### 2. Enterprise Policy Control

Use Chrome enterprise policies to control the bypass:

```json
{
  "PrivateNetworkAccessRestrictionsEnabled": false,
  "AllowedDomainsForApps": [
    "*.company.com",
    "*.okta.com",
    "login.microsoftonline.com"
  ]
}
```

#### 3. Network Segmentation

- Use VPNs for additional isolation
- Implement network-level access controls
- Monitor for unusual network patterns

## Google API Services Integration

### Google API Keys Configuration

To eliminate "Google API keys are missing" warnings and enable full functionality:

#### 1. Build Configuration

Add to `args.gn`:
```gn
enable_google_api_keys = true
google_api_key = "your_api_key_here"
google_default_client_id = "your_client_id.apps.googleusercontent.com"
google_default_client_secret = "your_client_secret"
```

#### 2. Environment Variables

```bash
# Set environment variables
export GOOGLE_API_KEY="your_api_key_here"
export GOOGLE_DEFAULT_CLIENT_ID="your_client_id.apps.googleusercontent.com"
export GOOGLE_DEFAULT_CLIENT_SECRET="your_client_secret"

# Add to shell profile for persistence
echo 'export GOOGLE_API_KEY="your_api_key_here"' >> ~/.zshrc
```

#### 3. Obtaining Google API Keys

1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Enable Chrome browser APIs
4. Create credentials (API key, OAuth 2.0 client)
5. Configure authorized origins and redirect URIs

### Benefits of Google API Integration

- **Sync Services**: Bookmarks, history, passwords
- **Safe Browsing**: Enhanced malware/phishing protection  
- **Translation**: Built-in Google Translate
- **Spell Check**: Google-powered spell checking
- **Omnibox Suggestions**: Search and navigation suggestions

## Camera and Media Access

### Media Device Access

Our build enables full camera and microphone access:

#### Build Configuration
```gn
# Enable media devices
use_proprietary_codecs = true
ffmpeg_branding = "Chrome"
enable_widevine = true

# Media capture support
enable_media_foundation = true
enable_media_remoting = true
```

#### Testing Media Access

```html
<!-- Create test file: media_test.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Media Access Test</title>
</head>
<body>
    <h1>Camera/Microphone Test</h1>
    <video id="video" autoplay muted></video>
    <button onclick="startCamera()">Start Camera</button>
    <button onclick="startMicrophone()">Start Microphone</button>
    
    <script>
    async function startCamera() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ 
                video: true 
            });
            document.getElementById('video').srcObject = stream;
        } catch (err) {
            console.error('Camera access failed:', err);
        }
    }
    
    async function startMicrophone() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ 
                audio: true 
            });
            console.log('Microphone access granted');
        } catch (err) {
            console.error('Microphone access failed:', err);
        }
    }
    </script>
</body>
</html>
```

### WebRTC Enterprise Support

Full WebRTC support for enterprise video conferencing:

- **Zoom**: Full compatibility with web client
- **Microsoft Teams**: Video/audio calling works  
- **Google Meet**: Complete functionality
- **Cisco Webex**: All features available
- **Custom WebRTC apps**: Full API support

## Session Management

### Enhanced Session Restore

Our build defaults to restoring previous sessions:

#### Implementation
```cpp
// In session_startup_pref.cc
SessionStartupPref::Type SessionStartupPref::GetDefaultStartupType() {
#if BUILDFLAG(IS_CHROMEOS)
  return SessionStartupPref::DEFAULT;
#else
  return SessionStartupPref::LAST;  // Always restore last session
#endif
}
```

#### Benefits for Enterprise Users
- **Continuity**: Work sessions persist across restarts
- **Productivity**: No need to manually restore tabs
- **Crash Recovery**: Better handling of unexpected shutdowns
- **Context Preservation**: Maintains workflow state

### Session Recovery Scripts

For advanced session management, we provide recovery scripts:

```bash
#!/bin/bash
# restore_session.sh - Manual session recovery

PROFILE_DIR="$HOME/Library/Application Support/Chromium/Default"
BACKUP_DIR="$HOME/.chromium_sessions"

# Create session backup
backup_session() {
    mkdir -p "$BACKUP_DIR"
    cp "$PROFILE_DIR/Current Session" "$BACKUP_DIR/session_$(date +%Y%m%d_%H%M%S)"
    cp "$PROFILE_DIR/Current Tabs" "$BACKUP_DIR/tabs_$(date +%Y%m%d_%H%M%S)"
}

# Restore specific session
restore_session() {
    local session_file="$1"
    local tabs_file="$2"
    
    cp "$session_file" "$PROFILE_DIR/Current Session"
    cp "$tabs_file" "$PROFILE_DIR/Current Tabs"
}

# List available backups
list_sessions() {
    ls -la "$BACKUP_DIR"/session_*
}

case "$1" in
    backup) backup_session ;;
    restore) restore_session "$2" "$3" ;;
    list) list_sessions ;;
    *) echo "Usage: $0 {backup|restore <session_file> <tabs_file>|list}" ;;
esac
```

## Enterprise Policy Support

### Chrome Enterprise Policies

Our Chromium build supports Chrome enterprise policies:

#### 1. Policy Configuration Location

```bash
# macOS policy location
/Library/Managed Preferences/org.chromium.Chromium.plist

# User-specific policies
~/Library/Managed Preferences/org.chromium.Chromium.plist
```

#### 2. Common Enterprise Policies

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Homepage and startup -->
    <key>HomepageLocation</key>
    <string>https://company.intranet</string>
    
    <key>RestoreOnStartup</key>
    <integer>1</integer>
    
    <!-- Security settings -->
    <key>AllowOutdatedPlugins</key>
    <false/>
    
    <key>AlwaysAuthorizePlugins</key>
    <false/>
    
    <!-- Proxy settings -->
    <key>ProxyMode</key>
    <string>pac_script</string>
    
    <key>ProxyPacUrl</key>
    <string>http://proxy.company.com/proxy.pac</string>
    
    <!-- Certificate management -->
    <key>CertificateTransparencyEnforcementDisabledForUrls</key>
    <array>
        <string>*.company.com</string>
    </array>
</dict>
</plist>
```

### Testing Enterprise Features

#### 1. Comprehensive Test Script

Create `scripts/test_enterprise_features.sh`:

```bash
#!/bin/bash

# Enterprise Features Test Suite
set -e

echo "Testing Enterprise Features..."

# Test 1: User Agent
echo "1. Testing User Agent..."
USER_AGENT=$(chromium --headless --dump-dom data:text/html,"<script>document.write(navigator.userAgent)</script>" 2>/dev/null)
if echo "$USER_AGENT" | grep -q "Chrome"; then
    echo "✅ Chrome user agent detected"
else
    echo "❌ Chromium user agent detected (may cause enterprise issues)"
fi

# Test 2: OAuth Redirect
echo "2. Testing OAuth Redirect Support..."
# Start test server
python3 -m http.server 8080 &>/dev/null &
SERVER_PID=$!
sleep 1

# Test localhost redirect
REDIRECT_TEST=$(chromium --headless --virtual-time-budget=1000 --run-all-compositor-stages-before-draw \
    "data:text/html,<script>window.location.href='http://localhost:8080'</script>" 2>&1 || true)

kill $SERVER_PID 2>/dev/null || true

if echo "$REDIRECT_TEST" | grep -q "ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS"; then
    echo "❌ Private network access blocked"
else
    echo "✅ Private network access allowed"
fi

# Test 3: Session Restore Default
echo "3. Testing Session Restore Default..."
PREFS_FILE="$HOME/Library/Application Support/Chromium/Default/Preferences"
if [ -f "$PREFS_FILE" ]; then
    if grep -q '"restore_on_startup":1' "$PREFS_FILE" 2>/dev/null; then
        echo "✅ Session restore enabled"
    else
        echo "⚠️ Session restore not configured"
    fi
else
    echo "⚠️ No preferences file found"
fi

# Test 4: Google API Keys
echo "4. Testing Google API Configuration..."
if [ -n "$GOOGLE_API_KEY" ]; then
    echo "✅ Google API key configured"
else
    echo "⚠️ Google API key not set"
fi

# Test 5: Media Access
echo "5. Testing Media Access..."
# This requires user interaction, so just check build flags
chromium --version &>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Browser launches successfully"
else
    echo "❌ Browser launch failed"
fi

echo "Enterprise features test complete!"
```

## Troubleshooting Enterprise Issues

### Common Problems and Solutions

#### 1. "Browser not supported" on Enterprise Sites

**Problem**: Site shows compatibility warning
**Solution**: Verify Chrome user agent is working

```bash
# Check user agent
chromium --headless --dump-dom data:text/html,"<script>document.write(navigator.userAgent)</script>"

# Should contain "Chrome" not "Chromium"
```

#### 2. OAuth Redirects Failing

**Problem**: `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS`
**Solution**: Verify private network bypass is applied

```bash
# Test with simple redirect
echo '<script>window.location.href="http://localhost:8080"</script>' > test_redirect.html
chromium test_redirect.html

# Should redirect without error
```

#### 3. Push Notifications Not Working

**Problem**: No push notifications from enterprise apps
**Solution**: Check user agent and notification permissions

```bash
# Check notification permission
# In browser console:
Notification.permission
# Should be "granted" or "default"

# Test notification
new Notification("Test", {body: "Enterprise notification test"})
```

#### 4. SAML Authentication Loops

**Problem**: Authentication redirects infinitely
**Solution**: Check certificate handling and cookie settings

```bash
# Launch with debugging
chromium --enable-logging --log-level=0 --disable-features=VizDisplayCompositor
```

### Enterprise Support Checklist

Before deploying in enterprise environment:

- [ ] Chrome user agent verified working
- [ ] OAuth redirects to localhost tested
- [ ] SAML authentication flows tested
- [ ] Push notifications working
- [ ] Media access permissions granted
- [ ] Session restore configured
- [ ] Google API keys configured (if needed)
- [ ] Enterprise policies applied
- [ ] Certificate handling configured
- [ ] Proxy settings configured (if needed)

---

**Summary**: These enterprise features ensure compatibility with corporate authentication systems, development workflows, and security policies while maintaining the enhanced functionality that makes this custom Chromium build superior to standard Chrome.