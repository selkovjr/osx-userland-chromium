## Tab Search URL Matching

**Date:** 2025-10-31

### Feature: Tab Search Matches Full URLs
- The tab search menu (Command-Shift-A) now matches and highlights full tab URLs, not just tab titles or hostnames.
- Implemented by adding a URL getter to the tab search filter keys in `tab_search_page.ts`.
- Patch: `patches/tab-search-url.patch`

#### How it works
- When searching in the tab search menu, entering any part of a tab's URL will match and highlight that tab in the results.
- This improves discoverability for users who remember URLs but not page titles.

#### Files changed
- `src/chrome/browser/resources/tab_search/tab_search_page.ts`

#### Patch location
- `osx-userland-chromium/patches/tab-search-url.patch`

#### Testing
- Verified that searching for URLs in the tab search menu works as expected.

---

## Omnibox Triple-Click Selection

**Date:** 2025-11-03

### Feature: Triple-Click Selects All Text
- Triple-click in the omnibox now selects all text, following standard macOS behavior.
- Properly distinguishes between double-click (select word) and triple-click (select all).
- Uses native `MouseEvent::GetClickCount()` from the system event API.
- Works both when omnibox is focused and unfocused.

#### How it works
- Uses the native click count provided by the UI event system.
- Single click (count=1): Positions caret only.
- Double click (count=2): Selects word at cursor position.
- Triple click (count>=3): Selects all text in the omnibox.
- Saves click location to handle deferred selection when clicking unfocused omnibox.

#### Files changed
- `src/chrome/browser/ui/views/omnibox/omnibox_view_views.h`
- `src/chrome/browser/ui/views/omnibox/omnibox_view_views.cc`

#### Patch location
- `osx-userland-chromium/patches/triple-click.patch`

#### Testing
- Verified that triple-click selects all text in both focused and unfocused omnibox.

---
