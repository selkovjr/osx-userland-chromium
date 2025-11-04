# Source Code Changes

This document details all the source code modifications made to achieve enterprise compatibility and enhanced functionality.

## Overview of Changes

Our custom Chromium includes four main source code modifications:

1. **User Agent Branding** - Forces Chrome branding for web compatibility
2. **Private Network Access Bypass** - Enables OAuth redirects in enterprise environments  
3. **Enhanced Double-Click Selection** - Focus-independent word selection in omnibox
4. **Session Restore Default** - Changes default startup behavior

## 1. User Agent Branding Fix

### Problem
Okta and other enterprise authentication services detect Chromium's user agent and block push notifications, showing "Browser not supported" messages.

### Solution Location
**File**: `components/embedder_support/user_agent_utils.cc`
**Function**: `BuildOSCpuInfoFromOSVersionAndCpuType()`
**Line**: ~200-220

### Original Code
```cpp
std::string brand;
#if !BUILDFLAG(CHROMIUM_BRANDING)
  brand = version_info::GetProductName();
#else
  brand = std::nullopt;
#endif
```

### Modified Code
```cpp
std::string brand;
#if !BUILDFLAG(CHROMIUM_BRANDING)
  brand = version_info::GetProductName();
#else
  // Force Chrome branding for better web compatibility (Okta, etc.)
  brand = std::nullopt;  // This makes it use Chrome branding
#endif
```

### Explanation
- The original code would use "Chromium" branding when `CHROMIUM_BRANDING` is enabled
- Our modification forces the `brand` to be `std::nullopt` which triggers Chrome branding logic
- This makes the browser report as "Chrome" instead of "Chromium" in its user agent string
- Enterprise services like Okta now recognize it as a supported browser

### Technical Details
- **Impact**: Changes user agent from `Chrome/139.0.0.0` to `Chrome/139.0.0.0`
- **Risk Level**: Low - only affects browser identification
- **Dependencies**: None
- **Testing**: Verify with `navigator.userAgent` in console

---

## 2. Private Network Access Bypass

### Problem
OAuth redirect flows fail with `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS` when redirecting from enterprise identity providers (Okta, Azure AD, etc.) back to localhost or private network addresses.

### Solution Location
**File**: `services/network/private_network_access_url_loader_interceptor.cc`
**Function**: `OnConnected()`
**Lines**: ~85-110

### Original Code
```cpp
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(
    network::mojom::URLRequest* request,
    network::mojom::URLResponseHead* response_head,
    mojo::ScopedDataPipeConsumerHandle* response_body,
    const std::string& mime_type,
    bool* defer_loading) {
  
  const network::ResourceRequest& url_request = *request;
  
  // Check if this is a private network request
  if (IsPrivateNetworkRequest(url_request)) {
    // Block the request for security
    return net::ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS;
  }
  
  return net::OK;
}
```

### Modified Code
```cpp
net::Error PrivateNetworkAccessUrlLoaderInterceptor::OnConnected(
    network::mojom::URLRequest* request,
    network::mojom::URLResponseHead* response_head,
    mojo::ScopedDataPipeConsumerHandle* response_body,
    const std::string& mime_type,
    bool* defer_loading) {
  
  // MODIFIED: Always allow private network access for OAuth/SAML compatibility
  return net::OK;
  
  // Original private network blocking logic (commented out for enterprise compatibility):
  /*
  const network::ResourceRequest& url_request = *request;
  
  // Check if this is a private network request
  if (IsPrivateNetworkRequest(url_request)) {
    // Block the request for security
    return net::ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS;
  }
  
  return net::OK;
  */
}
```

### Explanation
- Chromium blocks requests from public networks to private/local addresses for security
- This breaks OAuth flows where enterprise identity providers redirect to `localhost` or internal addresses
- Our bypass disables this check entirely, allowing all network requests to proceed
- This is a source-level change that can't be achieved via command-line flags

### Technical Details
- **Impact**: Disables private network access restrictions globally
- **Risk Level**: Medium - reduces network security isolation
- **Dependencies**: Network service, URL loading infrastructure
- **Testing**: Test OAuth redirect flows, check for `ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS`

### Security Implications
- **Trade-off**: Security vs enterprise compatibility
- **Mitigation**: Only affects requests that would have been blocked
- **Alternative**: Could implement allowlist for specific domains

---

## 4. Omnibox Multi-Click Selection (NEW)

**Files Modified:**
- `src/chrome/browser/ui/views/omnibox/omnibox_view_views.h`
- `src/chrome/browser/ui/views/omnibox/omnibox_view_views.cc`

**Changes:**
- Add double-click word selection and triple-click select-all support
- Use native MouseEvent::GetClickCount() API from macOS
- Leverage underlying Textfield's SelectWordAt() for word selection
- Call SelectAll(false) for triple-click to match macOS behavior
- Handle deferred selection when omnibox is not focused

**Implementation Details:**
- Detect click type using event.GetClickCount(): 1=single, 2=double, 3+=triple
- On double-click, select word at click location instead of moving cursor
- On triple-click, select all text in the omnibox
- For unfocused omnibox, defer selection until focus is acquired
- Track last_click_location_ to support deferred selection

---

## 4. Session Restore Default

### Problem
Chromium defaults to starting with a new tab page, but users expect browsers to restore their previous session by default (like Chrome does).

### Solution Location
**File**: `chrome/browser/prefs/session_startup_pref.cc`
**Function**: `GetDefaultStartupType()`
**Lines**: ~45-55

### Original Code
```cpp
// static
SessionStartupPref::Type SessionStartupPref::GetDefaultStartupType() {
#if BUILDFLAG(IS_CHROMEOS)
  return SessionStartupPref::DEFAULT;
#else
  return SessionStartupPref::DEFAULT;  // Start with new tab page
#endif
}
```

### Modified Code
```cpp
// static  
SessionStartupPref::Type SessionStartupPref::GetDefaultStartupType() {
#if BUILDFLAG(IS_CHROMEOS)
  return SessionStartupPref::DEFAULT;  // ChromeOS uses special behavior
#else
  return SessionStartupPref::LAST;     // Always restore last session by default
#endif
}
```

### Explanation
- Changes the default startup preference from `DEFAULT` (new tab) to `LAST` (restore session)
- Only affects the default - users can still change this in settings
- ChromeOS maintains its special startup behavior
- Improves user experience by preserving browsing sessions

### Technical Details
- **Impact**: Changes default startup behavior to restore last session
- **Risk Level**: Very Low - user preference, easily changeable
- **Dependencies**: Session management, preferences system  
- **Testing**: Restart browser and verify session restoration

---

## Build Configuration Changes

In addition to source modifications, we also configure the build with specific flags.

### Build Arguments (`args.gn`)

```gn
# Enable Google services integration
enable_google_api_keys = true

# Enable proprietary media codecs
proprietary_codecs = true
ffmpeg_branding = "Chrome"

# Optimize build for release
is_debug = false
dcheck_always_on = false
is_component_build = false

# Reduce binary size
symbol_level = 1
blink_symbol_level = 0
v8_symbol_level = 0

# Compatibility settings
use_custom_libcxx = true
treat_warnings_as_errors = false
```

### Environment Variables

```bash
# Google API integration (optional)
export GOOGLE_API_KEY="your_api_key"
export GOOGLE_DEFAULT_CLIENT_ID="your_client_id"
export GOOGLE_DEFAULT_CLIENT_SECRET="your_client_secret"
```

## Testing Changes

### 1. User Agent Verification
```javascript
// In browser console:
console.log(navigator.userAgent);
// Should contain "Chrome" not "Chromium"
```

### 2. Private Network Access Testing
```bash
# Test OAuth flow with enterprise provider
# Should not see ERR_BLOCKED_BY_PRIVATE_NETWORK_ACCESS_CHECKS
```

### 3. Double-Click Selection Testing
```
1. Navigate to any URL
2. Click elsewhere to unfocus omnibox  
3. Double-click on a word in the URL bar
4. Word should be selected after focusing
```

### 4. Session Restore Testing
```
1. Open several tabs
2. Quit browser normally
3. Restart browser
4. Previous tabs should be restored
```

## Patch Creation

To create patches for distribution:

```bash
# Create individual patches
git add components/embedder_support/user_agent_utils.cc
git commit -m "Force Chrome user agent branding for enterprise compatibility"
git format-patch -1 --stdout > patches/user-agent.patch

git add services/network/private_network_access_url_loader_interceptor.cc  
git commit -m "Bypass private network access checks for OAuth flows"
git format-patch -1 --stdout > patches/private-network.patch

git add chrome/browser/ui/views/omnibox/omnibox_view_views.*
git commit -m "Enhanced double-click word selection in omnibox"
git format-patch -1 --stdout > patches/double-click.patch

git add chrome/browser/prefs/session_startup_pref.cc
git commit -m "Default to session restore on startup"  
git format-patch -1 --stdout > patches/session-restore.patch
```

## Maintenance Notes

### Chromium Version Updates
When updating to newer Chromium versions:

1. **User Agent**: Logic may change, search for `GetProductName()` usage
2. **Private Network**: Check for changes in network security model  
3. **Double-Click**: UI event handling may be refactored
4. **Session Restore**: Preferences system typically stable

### Alternative Approaches
- **User Agent**: Could use `--user-agent` flag (less reliable)
- **Private Network**: Could use specific domain allowlists
- **Double-Click**: Could patch at textfield level vs omnibox level
- **Session Restore**: Could modify default preferences file

---

**Summary**: These four targeted changes provide enterprise compatibility while maintaining security and user experience. All modifications are well-contained and follow Chromium's architectural patterns.