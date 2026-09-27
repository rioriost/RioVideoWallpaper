# macOS 27.2 Beta 2 Compatibility Report

## Environment

| Item | Value |
| --- | --- |
| Investigation date | 2026-09-27 (JST) |
| Hardware | MacBook Air, Apple M3, arm64 |
| macOS | 27.2 beta 2, build 26B5091g |
| Xcode | 27.0, build 27A266a |
| macOS SDK | 27.0 |
| Swift | 6.4, swiftlang-6.4.0.34.1 |
| Metal compiler after installation | 32023.921 |
| Baseline commit | `26d9ee4` (Add macOS 27 support and bump version to 1.2.0) |

The final run used the baseline plus the test and Makefile fixes described below.
The default Metal device was verified as Apple M3 with unified memory and Metal 3 support.

## Findings and Fixes

### Missing Metal Toolchain

The initial Release build and test build failed before tests could run:

```text
cannot execute tool 'metal' due to missing Metal Toolchain
```

The GPU was available, but the separate Xcode compiler component was missing.
Installing it with the following command allowed shader compilation and the Release build to complete:

```sh
xcodebuild -downloadComponent MetalToolchain
```

This was a development-environment prerequisite, not an application runtime failure.

### UI Test Runner Signing

After installing the toolchain, all 84 unit tests passed, but the unsigned UI runner failed to establish its test connection and exited with a kill signal.
System logs recorded `Security policy would not allow process` for the UI runner.
Rebuilding with local ad-hoc signing allowed the UI tests to execute without changing macOS security settings.

The `Makefile` test target now enables signing with `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY=-`, and an empty `DEVELOPMENT_TEAM`.
No development certificate is needed. Release build signing behavior is unchanged.
The target also passes `TEST_RUNNER_VIDEO_WALLPAPER_UI_TESTING=1` so the hosted unit-test application does not present the initial video picker.

### Outdated Editor Assertions

The signed UI run executed seven test invocations: six passed and the editor test failed at its first obsolete button lookup.
Inspection found additional stale assertions in the same test:

| Old expectation | Current UI checked by the repaired test |
| --- | --- |
| `Export...` | `Export` |
| `Set as Wallpaper` | `Set to All Displays` |
| `Provider` and `Intent` | `Export Options` and `Renderer Options` |

`testGenerativeEditorOpensFromLaunchEnvironment()` now checks the current editor.
The test helper supplies `-AppleLanguages (en)` and `-AppleLocale en_US` to the application so English label assertions do not depend on the Mac's preferred language.
No application behavior or production UI was changed to satisfy the test.

## Final Results

| Check | Result |
| --- | --- |
| Release build, arm64, signing disabled | Passed after Metal Toolchain installation |
| Unit tests | 84 passed |
| UI test invocations | 7 passed |
| Total invocations | 91 passed, 0 failed, 0 skipped |
| Final xcresult runtime warnings | 0 |

The final `make test` run completed at approximately 16:01 JST.
It used an isolated `DERIVED_DATA` directory outside the repository; no additional signing overrides were supplied on the command line.
The result bundle reports 88 distinct tests and 91 invocations because the launch test runs in four UI configurations.

The successful unit run includes Metal thumbnail rendering, H.264 movie export and output validation for Field Lines, Orbital, Soft Volumetric, and Grid City, export cancellation, project persistence, and playback-suspension policy checks.
The UI run includes application launch and the repaired editor-control checks.
Raw logs and xcresult bundles were retained locally and are not committed.

## Reproduction

With Xcode selected and its Metal Toolchain installed, run:

```sh
make build
make test
```

To keep build and test artifacts outside the repository, override `DERIVED_DATA` with a writable directory when invoking either target.

## Scope and Limitations

The existing automated checks passed on this Mac after correcting the toolchain setup, test signing, and outdated assertions.
This is not an exhaustive compatibility certification.
Long-running desktop wallpaper playback, actual sleep/wake recovery, physical multi-display changes, login-item behavior, and distribution signing/notarization were not validated.
The label-based editor test runs in English and does not validate Japanese translations.
