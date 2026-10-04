# User guide

[Project home](../../README_EN.md) · [Detection methods](DETECTION.md) · [Build guide](BUILDING.md) · [简体中文](../USAGE.md)

## Installation

1. Open [GitHub Releases](https://github.com/AkiSenn/JailPrism/releases/latest).
2. Download `JailPrism-<version>-unsigned.ipa` from Assets. Use `SHA256SUMS.txt` on the same page to check file integrity.
3. Share the IPA with TrollStore to install it.

For development builds, select a successful [GitHub Actions](https://github.com/AkiSenn/JailPrism/actions/workflows/build.yml) run, download `JailPrism-unsigned-iOS14-arm64-arm64e`, and extract `JailPrism-unsigned.ipa`.

The app requires iOS 14.0 or later and includes arm64 and arm64e. The app's system requirement and TrollStore's installation support are separate; not every iOS 14+ system can install through TrollStore.

The distributed IPA is completely unsigned, with no ad-hoc signature, signature resources, provisioning profile or embedded entitlements. Runtime privileges depend on the installer configuration.

## Results

The app scans automatically at launch. The top of the main page shows the device model, hardware identifier, iOS version and build number, completion time with time zone, scan duration and score. Normal mode then shows detected environments and suspected jailbreak types. Tap **Recheck** to refresh.

Professional mode adds these filters:

| Filter | Contents |
| :--- | :--- |
| All | Every check in this scan |
| Hits | Checks with detected indicators |
| Unknown | Restricted, unavailable or otherwise inconclusive checks |
| Groups | User, primary group and supplementary groups of the detector process |

Normal mode has no technical footer. TrollStore hits are named explicitly, and jailbreak results show the suspected family, such as Rootless. Stores and injected libraries are listed separately, with duplicate names merged and subsequent names aligned:

```text
Detected Cydia
         Sileo

Detected Choicy.dylib
         ShadowCore.dylib
```

The app aligns labels with layout constraints rather than fixed spaces. Library names come from known injection indicators in loaded images or resolved function origins. An existing file alone is not reported as a loaded library. This list does not verify signing legality.

## Professional user mode

Open **Gear → Display mode → Professional user mode**. It is off by default and your choice is saved. Enable it to see all checks, paths, weights, scoring rules, statuses and technical notes, plus the filters above. Switching display mode reuses the current report without changing the score or enabling private APIs.

A check's displayed weight is not necessarily its final deduction: group caps and correlation discounts affect the total. See [scoring](DETECTION.md#scoring).

User/group anomalies describe the detector process relative to the mobile (501) baseline. They are not a history of system activity or an audit of other apps. The existence of normal system accounts is not an anomaly.

## Language

Open **Gear → Language**:

| Option | Behavior |
| :--- | :--- |
| Follow system | Default: Simplified and Traditional Chinese both select `zh_Hans_CN`; other languages select `en_US` |
| English | Always use `en_US` |
| 简体中文 | Always use `zh_Hans_CN` |

Traditional Chinese system languages, including Taiwan and Hong Kong, use Simplified Chinese in the app. The choice is saved. Returning to the main page after a language change triggers a scan in the selected language. The settings page does not show a language-mapping footer.

## Private APIs

Open **Gear → Extended environment checks → Use private APIs**. The switch is off by default and your choice is saved.

| Mode | Scope |
| :--- | :--- |
| Standard | Public file and URL queries, process identity, dyld images, function origins and runtime properties |
| Extended | Standard checks plus private URL handlers, tool registration, randomized bootstrap directories, privileges, sandbox queries, daemons, Mach services and read-only ARM64 kernel probes |

This option is available for apps installed through In-House (Enterprise) distribution or TrollStore. The terminology follows [Apple's provisioning profile documentation](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles). It grants no additional privileges and cannot guarantee bypassing Shadow, Choicy or RootHide hiding mechanisms.

When off, extended checks and raw SVC probes are not called; they are skipped. Insufficient permissions or unavailable private interfaces produce unknown results. Neither state is treated as a passed check.

## Report export

Tap **Share** to save or share `JailPrism-report.json`.

| Field | Contents |
| :--- | :--- |
| `device` | Model, hardware identifier, iOS version, build number, execution architecture and simulator flag |
| `scanTime` / `scanDuration` | Completion time and elapsed time |
| `scanConfiguration` | Scan mode, private API setting and attempted extended operations |
| `identity` | Process UID/GID, effective identity and supplementary groups |
| `score` | Score, group deductions, correlation discount and evidence contributions |
| `classification` | Suspected types, evidence IDs and TrollStore classification |
| `findings` | Status, weight and evidence for each check; file checks also include query channels |
| `simpleSummary` | Normal-mode name lists and evidence IDs |
| `presentationMode` | Normal or professional display mode at export time |

The report uses `schema: 2`. `scanConfiguration.privateOperationsAttempted` records whether extended operations were attempted.

The app does not connect to the network. Reports are exported only when you share them. Detection does not escalate privileges, jailbreak the device, inject other processes, install or delete files, write to system paths, open URLs or send Mach service messages.

## Incorrect or missed results

Record the iOS version, model, jailbreak tool, installer, hiding plugins and private API setting. Export the JSON report and follow [contributing instructions](CONTRIBUTING.md).

Physical-device checks in the simulator are unknown with zero weight. Simulator results cannot establish whether a physical device is jailbroken.

## Project notice and credits

The AI-generation notice and acknowledgments to Codex and GPT-6.1 Sol appear in the [project README](../../README_EN.md) only. They are not displayed in app settings.
