# Contributing and reporting issues

[Project home](../../README_EN.md) · [Build guide](BUILDING.md) · [简体中文](../../CONTRIBUTING.md)

## Missed detections, false positives or crashes

Open an [issue](https://github.com/AkiSenn/JailPrism/issues), include reproduction steps and provide:

| Information | Example |
| :--- | :--- |
| App version | 1.2.2 |
| Device and system | iPhone XR / iOS 14.8 |
| Jailbreak tool and version | Taurine, unc0ver, Dopamine or a RootHide variant |
| Installation method | TrollStore or In-House (Enterprise) distribution |
| Hiding and injection configuration | Shadow, Choicy, whether injection into the detector is enabled |
| Private APIs | On or off |
| Professional user mode | On or off |
| Expected and actual results | Expected family, actual score and hit findings |
| Detection report | The corresponding `JailPrism-report.json` |

For UI issues, include the language selection and a screenshot. Remove unrelated personal path or identity details if needed; retain the relevant check IDs, statuses and query-channel results.

## Code changes

1. Address a specific problem and describe the resulting behavior and validation.
2. Document sources, applicable environments, weights and visibility limits for new evidence.
3. Do not treat permission denial, unavailable interfaces or skipped checks as passed.
4. Gate new private interfaces behind extended mode and keep the default off.
5. Add both `en_US` and `zh_Hans_CN` resources for user-visible strings.
6. Regenerate the Xcode project after adding sources or resources.

Changes to scoring, classification or language behavior should have meaningful regression checks. Documentation and screenshot changes require checking links, rendering and consistency with the implementation.

## Validation

On Windows or macOS:

```bash
python scripts/check_localizations.py
```

For a full build on macOS:

```bash
bash scripts/build.sh
```

Windows users can run GitHub Actions with **Run workflow** and select the branch to validate. Device packages must remain dual-architecture, compatible with iOS 14.0 and completely unsigned.
