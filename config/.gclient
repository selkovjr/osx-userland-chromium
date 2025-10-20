# .gclient configuration for Custom Chromium
# This file configures the depot_tools sync process

solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {},
    "custom_vars": {
      # Optimize sync for macOS development
      "checkout_mac": True,
      "checkout_ios": False,
      "checkout_win": False,
      "checkout_linux": False,
      "checkout_android": False,
      "checkout_chromeos": False,
      
      # Additional repositories
      "checkout_nacl": False,
      "checkout_pgo_profiles": True,
    },
  },
]

# Target OS for optimization
target_os = ["mac"]

# Cache settings for faster syncs
cache_dir = None