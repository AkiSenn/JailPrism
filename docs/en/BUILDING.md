# Build guide

[Project home](../../README_EN.md) · [User guide](USAGE.md) · [Detection methods](DETECTION.md) · [简体中文](../BUILDING.md)

## Project structure

```text
JailPrism/
├── Sources/                  # UIKit UI, detection, scoring, settings and localization
├── Tests/                    # Foundation regression checks
├── scripts/                  # Project generation, builds and validation
├── JailPrism.xcodeproj/       # Generated Xcode project
├── Artwork/                  # App icon and documentation artwork
├── docs/                     # Chinese guides and English guides in en/
└── .github/workflows/        # GitHub Actions cloud builds
```

The app uses Objective-C and UIKit with no third-party code dependencies. Device builds require iOS 14.0 and include arm64 and arm64e. The Bundle ID is `com.akisenn.JailPrism`.

## GitHub Actions

Windows users can use [Build unsigned JailPrism IPA](https://github.com/AkiSenn/JailPrism/actions/workflows/build.yml):

1. Open the workflow page.
2. Select **Run workflow** and choose `main`.
3. Wait for success and download `JailPrism-unsigned-iOS14-arm64-arm64e`.

Code pushes to `main` also trigger a build. Documentation-only changes covered by `paths-ignore` do not. The runner uses `macos-15`; artifacts are retained for 30 days.

| Artifact | Contents |
| :--- | :--- |
| `JailPrism-unsigned.ipa` | Completely unsigned, dual-architecture device package |
| `build-metadata.json` | Architectures, minimum OS, version and unsigned verification |
| `SHA256SUMS.txt` | IPA SHA-256 |
| `simulator-*.png` | Main-page and settings screenshots |
| `simulator-*-report.json` | Reports for language and display-mode cases |
| `simulator-smoke.txt` | Simulator validation results |
| `*build.log` | Device and simulator build logs |

Failed runs also upload whatever logs or artifacts were generated. Use a package from a run that succeeded as a whole.

## GitHub Releases

Verified builds can also be published to [Releases](https://github.com/AkiSenn/JailPrism/releases) with a versioned unsigned IPA, `SHA256SUMS.txt` matching that filename, `build-metadata.json` and simulator results. Release assets are not subject to the Actions artifact retention period.

Before publishing, verify the version, architectures, unsigned status and hash. Assets should come from a successful cloud build. If a release tag includes later documentation commits, confirm that app sources and build configuration match the verified build commit. The current workflow uploads Actions artifacts; maintainers publish releases separately.

## Generate the project

With Python 3 on Windows or macOS, run from the repository root:

```bash
python scripts/generate_project.py
```

The script generates `JailPrism.xcodeproj`. Run it again after adding source files or language directories. Direct edits to the generated project can be overwritten.

## Build on macOS

Install Xcode, the iOS SDK, Python 3 and the configured Xcode command-line tools, then run:

```bash
bash scripts/build.sh
```

The output is `dist/JailPrism-unsigned.ipa`. The script disables Xcode signing and device-linker ad-hoc signing. It does not invoke a signing tool.

Check language resources independently with:

```bash
python scripts/check_localizations.py
```

## CI validation

| Check | Validation |
| :--- | :--- |
| Language resources | Matching keys and format placeholders in both languages |
| Scoring and settings | URL classification, score caps, type evidence, deduplicated names, language mapping, disabled defaults and saved preferences |
| Device package | arm64/arm64e, minimum iOS 14.0, neither slice contains `LC_CODE_SIGNATURE` |
| Signature resources | No `_CodeSignature`, provisioning profile or embedded entitlements |
| Simulator | Languages, normal/professional pages, extended inspection, Chinese/English settings and multiline name fixtures |

Simulator checks confirm that the app process remains alive and validate report structure, device information, timestamps and mode switches. `scanConfiguration.privateOperationsAttempted` is empty in standard mode and records attempted operations in extended mode.

The simulator cannot establish real-device jailbreak detection accuracy. Record the system, jailbreak tool, hiding plugins, installer and JSON report during physical-device testing.

Multiline previews use explicitly marked `previewFixture: true` reports. They respond only to simulator test arguments. `TARGET_OS_SIMULATOR` excludes the fixture entry point from device IPAs.
