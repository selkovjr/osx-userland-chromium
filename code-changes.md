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
