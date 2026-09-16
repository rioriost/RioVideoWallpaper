# App Store Review Preflight — 2026-09-16

- App / platform: RioVideoWallpaper / macOS
- Version / build: 1.2.1 / 5
- Bundle ID: st.rio.VideoWallpaper
- App Store Connect ID: 6783258615
- Submission type: update from published 1.2.0 (4)
- Guidelines checked: retrieved 2026-09-16
- Source: 705f8f9 plus the localized Privacy Policy menu link added during this submission preparation.
- Submission status: Waiting for Review (審査待ち), verified in App Store Connect after the developer submitted version 1.2.1.
- Preparation handoff: the agent paused before final submission because review contact telephone/email appeared empty in the form.
- Preparation-time findings: one contact-information concern and one runtime-qualification warning. The contact concern did not prevent the developer from completing submission; contact values were not re-inspected or recorded.

## Findings

### Preparation-time concern — Review contact telephone and email

Both fields appeared empty in the 1.2.1 App Review information form during preparation. First and last names were present. The developer subsequently completed submission, and the app is now Waiting for Review. No contact details were inferred from unrelated records or stored in this report.

Source: [App Review Guidelines 2.1(a), Before You Submit](https://developer.apple.com/app-store/review/guidelines/#app-completeness).

### WARNING — Runtime qualification scope

Tests ran on Apple Silicon Mac Studio with macOS 27.0 (26A428). The archive contains arm64 and x86_64 and supports macOS 26.0+, but this run did not perform runtime testing on Intel or macOS 26. This is a verification limitation, not an observed failure.

Source: [App Review Guidelines 2.1(a), 2.4](https://developer.apple.com/app-store/review/guidelines/#performance).

## Coverage summary

| Family | Status | Evidence |
|---|---|---|
| Safety | PASS | Local utility, abstract procedural graphics, user-selected local files; no hosted UGC, messaging, health or regulated service. Existing support URL returns HTTP 200. |
| Performance | WARNING | Final archive verified; 138 baseline tests passed and final UI suite passed. Runtime qualification remains limited as stated above. |
| Business | PASS | Free in App Store Connect; no purchases, subscriptions or ads in source or review flow. |
| Design | PASS | Native menu bar utility with local video playback, multi-display assignment, procedural generation, preview, export and library; existing app update. |
| Legal | PASS for technical/declaration checks | App Sandbox and user-selected read-write only; privacy manifest declares no collection/tracking; App Store privacy says no data collected. Existing content-rights declaration says no third-party content. Existing trader declaration present; no legal determination made. |
| Metadata and build identity | PASS | Japanese/English release notes saved; review steps saved; 1.2.1 (5) uploaded and selected; Japanese screenshots inspected, English screenshot assets present. |

Not applicable groups: account/login/deletion; IAP/subscriptions/advertising; hosted UGC/social/remote AI services; regulated domains/gambling/VPN/MDM/extensions/Game Center.

## Remediation completed

App Review Guideline 5.1.1(i) calls for an in-app privacy-policy link. Added a localized Privacy Policy item to the menu bar, using the existing App Store Connect privacy URL. The URL returns HTTP 200 and describes local files, optional launch at login and no data collection. Rebuilt before upload.

## Build and upload evidence

- Xcode 27.0 (27A266a), macOS 27 SDK, minimum macOS 26.0.
- Final archive: `build/AppStore-1.2.1-5/RioVideoWallpaper-final.xcarchive`.
- Archive log: `build/AppStore-1.2.1-5/archive-final.log` — ARCHIVE SUCCEEDED.
- Inspection: `build/AppStore-1.2.1-5/inspection.json`; strict code signature verification passed.
- Full test result: `build/DerivedData/Logs/Test/Test-RioVideoWallpaper-2026.09.16_17-34-54-+0900.xcresult` — 138 tests, zero failures.
- Final UI result: `build/DerivedData/Logs/Test/Test-RioVideoWallpaper-2026.09.16_17-38-26-+0900.xcresult` — 4 tests / 7 executions, zero failures.
- Upload log: `build/AppStore-1.2.1-5/upload.log` — Upload succeeded at 17:39:23 JST; EXPORT SUCCEEDED.
- Apple processing completed: build 1.2.1 (5) became selectable at 17:40 JST.
- Selected build ID: b6f377bd-a0fc-45c7-866b-208be193d5d5.
- Existing release settings: automatically release after approval, all users; existing ratings retained.
- Existing availability: 148 available territories, 27 unavailable; not changed.

## Evidence reviewed

Source, Info.plist, entitlements, PrivacyInfo.xcprivacy, settings/menu UI, local metadata/review drafts, signed bundle, full tests and final UI tests. App Store Connect: version metadata/localizations/screenshots, review notes/contact fields, build selection, sandbox justification, privacy, app information/age rating/content rights/trader declaration, price/availability/release settings. Privacy and support URLs reachable. No independent legal opinion or Intel/macOS 26 runtime evidence.

## Submission outcome

The submitted build is the final audited 1.2.1 (5) archive. The agent added the version to a review draft at 17:42 JST. The developer performed the final submission and reported completion. A subsequent read-only check of App Store Connect confirmed version 1.2.1 is Waiting for Review (審査待ち). Approval and public release remain pending.

App Store Connect: https://appstoreconnect.apple.com/apps/6783258615/distribution/macos/version/inflight
