# Changelog: Custom Chromium Enterprise Build

## 2025-10-31

### Omnibox Double-Click Selection & Caret Behavior
- Single click in omnibox positions caret only (no selection, no suggestions).
- Double-click selects the word under the cursor, regardless of focus state.
- Suggestions dropdown suppressed unless field is empty and user begins typing.
- Uses `Textfield::SelectWordAt` for robust word selection.
- Handles deferred selection when double-clicking an unfocused omnibox.
- All changes in `chrome/browser/ui/views/omnibox/omnibox_view_views.h` and `.cc`.

### URL Elision Disabled by Default
- Full URL always visible and editable in omnibox.
- Controlled by `omnibox::kPreventUrlElisionsInOmnibox` (default: true).
- No manual pref change required; default is "no elide".

### User Agent Branding Fix
- Forces Chrome branding in user agent for enterprise compatibility (Okta, etc.).
- Sets brand to `std::nullopt` to trigger Chrome branding logic.
- Change in `components/embedder_support/user_agent_utils.cc`.

### Private Network Access Bypass
- Disables private network access checks for OAuth/SAML flows.
- Always returns `net::OK` in `OnConnected()`.
- Change in `services/network/private_network_access_url_loader_interceptor.cc`.

### Session Restore Default
- Browser restores previous session by default (except ChromeOS).
- Changes default startup type to `LAST` in `chrome/browser/prefs/session_startup_pref.cc`.

### Build Configuration
- Proprietary codecs, Google API keys, optimized release build, custom libcxx, warnings not treated as errors.
- All changes documented in `docs/code-changes.md` and `docs/build-guide.md`.

### Patch Management
- All changes can be exported as patches for future maintenance:
  - `patches/user-agent.patch`
  - `patches/private-network.patch`
  - `patches/double-click.patch`
  - `patches/session-restore.patch`

---

For full technical details, see `docs/code-changes.md` and `docs/build-guide.md`.
