# Changelog

[Project home](../../README_EN.md) · [简体中文](../../CHANGELOG.md)

## 1.2.2 · 2026-10-04

- Use Apple's In-House (Enterprise) distribution terminology in the private API settings description; Chinese uses 企业内部分发（In-House）.
- Add an English README, user guide, detection guide, build guide, contributing guide and changelog. Chinese remains the default project page.
- Provide verified unsigned IPA packages and checksums through GitHub Releases.

## 1.2.1 · 2026-10-04

- Remove the language-mapping footer from settings while preserving Follow system and automatic language selection.
- Remove AI-tool credits and their icon from the app; keep them in GitHub documentation only.
- Update Chinese and English simulator settings previews.

## 1.2.0 · 2026-10-04

### Added

- Default normal mode with device information, score, suspected environments and detected names.
- Professional user mode retaining all checks, paths, weights and technical notes.
- Deduplicated, aligned multiline Cydia/Sileo/Zebra and known injected library lists.
- Settings credits for Codex and GPT-6.1 Sol, with the OpenAI icon and AI-generation notice. These were removed from the app in 1.2.1.
- Normal-mode summaries and presentation mode in JSON reports; display and private API settings remain independent.

### Renamed

- App and project renamed to JailPrism.
- Bundle ID changed to `com.akisenn.JailPrism`.
- Xcode project, build artifacts and report filenames updated.

### Validation

- Regressions for summary deduplication, exclusion of unknown findings, library origins and professional mode disabled by default.
- Simulator checks for both main pages, languages, private mode and credits; illustrative data is simulator-only and explicitly marked.
- Retain iOS 14.0, arm64/arm64e and completely unsigned IPA distribution.

## 1.1.0 · 2026-10-04

### Added

- Evidence-based rootful/rootless/roothide classification, including overlapping types and evidence IDs.
- Device model, hardware identifier, iOS version/build number, scan time and duration.
- Language selection and private API settings, with private APIs off by default.
- `en_US` and `zh_Hans_CN`; Traditional Chinese system languages select Simplified Chinese resources.
- Extended URL handler, app registration, randomized bootstrap directory, sandbox, daemon, Mach service and read-only ARM64 kernel checks.

### Improved

- Taurine/libhooker, unc0ver/Substitute, Dopamine/ElleKit and RootHide/Relaxin indicators.
- File query comparison across channels to record possible filtering or state changes.
- Tool registration no longer infers rootless status from Sileo, Zebra or Dopamine names alone.
- Skipped and unknown findings are distinct; TrollStore evidence alone does not establish a jailbreak.
- Report schema 2 includes type evidence, scan configuration and attempted extended operations.
- Language mapping, setting defaults and simulator-mode validation.

### Build

- Retain iOS 14.0, arm64/arm64e and completely unsigned IPA distribution.
- Retain the white-background app icon.

## 1.0.0 · 2026-10-04

- First native environment detector covering rootful, rootless, roothide and TrollStore indicators.
- Scoring, finding filters, user/group checks and JSON export.
- GitHub Actions builds for iOS 14+ and both architectures.
- Completely unsigned package with a white-background app icon.
