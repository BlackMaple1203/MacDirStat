# Release Prep Report — v1.0

**Date:** 2026-05-07
**Version:** 1.0 (Build 1)
**Release Type:** Initial App Store Submission
**Platform:** macOS 26.0+
**Status:** BLOCKED — 1 required fix before submission

---

## Version

- MARKETING_VERSION: 1.0 (no bump needed — first release)
- CURRENT_PROJECT_VERSION: 1

---

## Changelog

### What's New in 1.0 (App Store "What's New" — copy-paste ready)

```
Welcome to DirStat!

• Instantly visualize what's taking up space on your Mac with an interactive treemap
• Real-time monitoring — the view updates automatically as files change
• Smart safety detection flags system folders to prevent accidental deletion
• Accurate disk usage with full deduplication of hardlinked files
• Liquid Glass design built for macOS 26
• Full Disk Access support for a complete picture of your storage
```

---

## Code Readiness

| Check | Status | Notes |
|-------|--------|-------|
| Debug prints removed | ✓ | None outside #if DEBUG |
| No blocking TODOs | ✓ | None found |
| ATS clean | ✓ | No NSAllowsArbitraryLoads |
| Swift optimization (Release) | ✓ | -O |
| Third-party packages | ✓ | None (Sparkle removed) |
| Hardcoded test data | ✓ | None found |

---

## Privacy & Compliance

| Check | Status | Notes |
|-------|--------|-------|
| **Privacy manifest (PrivacyInfo.xcprivacy)** | **✗ BLOCKER** | **Required for App Store. Must declare UserDefaults API reason.** |
| App sandbox enabled | ✓ | com.apple.security.app-sandbox = true |
| Entitlements minimal | ✓ | user-selected.read-only only |
| Full Disk Access description | ✓ | NSFullDiskAccessUsageDescription present |
| ATS configured | ✓ | No exceptions |
| Third-party privacy manifests | ✓ N/A | No third-party packages |

### Fix required: Create PrivacyInfo.xcprivacy

The app uses UserDefaults (11 call sites). Apple requires a reason code declaration.
Reason code to use: `CA92.1` ("App reads and writes UserDefaults for user preferences.")

---

## App Store Metadata

| Check | Status | Notes |
|-------|--------|-------|
| App icon complete | ✓ | All sizes present including 1024x1024 |
| App display name | ✓ | CFBundleDisplayName = "DirStat" |
| Category | ✓ | public.app-category.utilities |
| Launch screen | ✓ N/A | Not required for macOS apps |
| Screenshots | ⚠ Unknown | Must be uploaded in App Store Connect (1280x800 or 1440x900 for macOS) |
| Support URL | ⚠ | Add to Info.plist or set in App Store Connect |
| Privacy Policy URL | ⚠ | Required in App Store Connect if app collects any data |
| What's New text | ✓ | See above |

---

## Signing

| Check | Status | Notes |
|-------|--------|-------|
| Development team | ✓ | L4UH9K7AW4 |
| Code sign identity | ⚠ | Currently "Apple Development" — Xcode auto-selects "Apple Distribution" at archive time if set to automatic |
| Deployment target | ⚠ | macOS 26.0 — very new, limits audience to macOS 26 users only |

---

## Blockers Before Submission

### 1. Create PrivacyInfo.xcprivacy (REQUIRED)

Create `MacDirStat/PrivacyInfo.xcprivacy` with this content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Then add it to the Xcode target (Target → Build Phases → Copy Bundle Resources).

---

## Release Commands (after fixing blockers)

```bash
# Build archive (or use Xcode: Product → Archive)
xcodebuild archive \
  -scheme MacDirStat \
  -archivePath build/MacDirStat.xcarchive \
  -configuration Release

# Tag the release after successful submission
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

---

## Post-Release Monitoring

- [ ] Verify app passes App Store review
- [ ] Monitor crash reports for 48 hours after launch
- [ ] Check App Store reviews
- [ ] Verify "Check for Updates" button is removed or updated (Sparkle removed, currently posts notification with no handler)
