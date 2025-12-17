# Changelog: Custom Chromium Enterprise Build

## 2025-11-04

### Fixed: Google Search Queries from Omnibox
- Fixed regression where Google search queries from the omnibox were not working.
- The case-sensitive URL matching patch was incorrectly overriding search query matches.
- Now properly detects search queries and skips the verbatim match override for them.
- Search queries now work correctly while URL case-sensitivity is still preserved.
- Patch: `patches/history-case-sensitive.patch` (updated)

### Omnibox Multi-Click Selection (Combined Patch)
- Combined double-click and triple-click functionality into single comprehensive patch.
- Single-click positions caret, double-click selects word, triple-click selects all.
- Uses native `MouseEvent::GetClickCount()` from the system event API.
- Works both when omnibox is focused and unfocused.
- All changes in `chrome/browser/ui/views/omnibox/omnibox_view_views.h` and `.cc`.
- Patch: `patches/omnibox-multiclick.patch`
- Note: This supersedes the separate `double-click.patch` and `triple-click.patch`.

## 2025-11-03

### Omnibox Triple-Click Selection
- Triple-click in omnibox now selects all text (standard macOS behavior).
- Properly distinguishes between double-click (select word) and triple-click (select all).
- Uses native `MouseEvent::GetClickCount()` from the system event API.
- Works both when omnibox is focused and unfocused.
- All changes in `chrome/browser/ui/views/omnibox/omnibox_view_views.h` and `.cc`.
- Patch: `patches/triple-click.patch`
- **Note: Use `omnibox-multiclick.patch` instead for new builds.**

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
  - `patches/omnibox-multiclick.patch` (combined double/triple-click)
  - `patches/session-restore.patch`
  - `patches/tab-search-url.patch`
- Legacy patches (superseded by omnibox-multiclick.patch):
  - `patches/double-click.patch` (original implementation)
  - `patches/triple-click.patch` (improved implementation)

### Tab Search URL Matching
- Tab search menu (Command-Shift-A) now matches and highlights full tab URLs, not just tab titles or hostnames.
- Implemented in `src/chrome/browser/resources/tab_search/tab_search_page.ts`.
- Patch: `patches/tab-search-url.patch`

---

For full technical details, see `docs/code-changes.md` and `docs/build-guide.md`.
