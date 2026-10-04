# Detection methods

[Project home](../../README_EN.md) · [User guide](USAGE.md) · [Build guide](BUILDING.md) · [简体中文](../DETECTION.md)

## Environment coverage

| Environment or framework | Main indicators |
| :--- | :--- |
| Taurine, rootful | libhooker, libblackjack, TweakInject, `/taurine/jailbreakd`, amfidebilitate, pspawn and `org.coolstar.jailbreakd` |
| unc0ver, rootful | Substitute, Cydia, apt/dpkg and historical bootstrap markers |
| MobileSubstrate | Injection directories, related libraries and loaded images |
| Dopamine, rootless | `/var/jb`, basebin, libjailbreak, ElleKit and procursus paths under `dopamine-*` or `jb-*` in Preboot |
| Dopamine RootHide, Relaxin/RelaxinLite | `.jbroot` links, randomized `.jbroot-*` directories, dpkg/basebin corroboration, libroothide, injection paths and known registration IDs |
| ElleKit | libellekit, libinjector, pspawn, loader, TweakInject/TweakLoader, compatibility symlinks and loaded images |
| TrollStore/TrollStoreLite | `_TrollStore`/`_TrollStoreLite` markers, tool directories, registration IDs and actual URL handlers |

Taurine uses libhooker; Substitute indicators cover environments such as unc0ver. ElleKit checks cover rootful and rootless paths. Evidence within a RootHide path is classified as roothide.

Tool registration, randomized directory discovery and additional service queries require private API mode. Known IDs do not cover every renamed variant.

## Methods

### File query comparison

The same path is checked using `lstat`, `stat`, `access`, read-only `open` and FileManager. Path findings export each channel's status and available errno values. Readable attributes include ownership, permissions and symlink targets.

Extended mode adds a read-only SVC entry point on physical ARM64 devices. It accepts only a path and cannot create or write files. When a kernel query succeeds while both libc `lstat` and `open` report absence, the app reports possible filtering or a filesystem state change.

Raw SVC queries can also be intercepted. Contradictory queries are evidence, not proof that Shadow was bypassed.

### URLs and tool registration

Standard mode uses public `canOpenURL` availability checks. Extended mode queries LaunchServices for actual URL handlers and related tool registrations.

TrollStore handlers must exactly match `com.opa334.TrollStore` or `com.opa334.TrollStoreLite`. The system `com.apple.Magnifier` handler alone is not evidence. Detection queries handlers without opening URLs or triggering installation.

### Identity and runtime

- Current-process UID/EUID/GID/EGID, group names and membership.
- dyld images and `dladdr` origins of public functions.
- DYLD injection environment variables and root filesystem mount flags.
- Extended-mode privileges, sandbox read policies, known jailbreak daemons and Mach service lookups.

On arm64e, function addresses have PAC removed before they are passed to `dladdr`; code pointers are not manually dereferenced. Process enumeration retains matches for known jailbreak daemons only. Mach service checks look up ports without sending messages.

## Classification

Classification and scoring are independent. Hit evidence is classified using its actual path, group or explicit type hint:

| Type | Conclusion |
| :--- | :--- |
| `rootful` | Suspected rootful jailbreak |
| `rootless` | Suspected rootless jailbreak |
| `roothide` | Suspected hidden-root jailbreak |

Multiple families are preserved when evidence overlaps. Reports include evidence IDs for each family. TrollStore alone does not establish a jailbreak. Generic injection evidence can leave the family undetermined.

Regular Dopamine and its RootHide variant may share a Bundle ID, so names alone cannot distinguish them. Sileo or Zebra installations do not establish rootless status. Installed tools and leftover directories do not prove that a jailbreak is currently active.

## Scoring

The base score is 100. Hit deductions are deduplicated by check ID and capped by group. Total deduction cannot exceed 100.

| Evidence group | Maximum deduction |
| :--- | ---: |
| rootful/rootless/roothide | 45 per group, with a shared total cap of 45 |
| Injection and filtering | 35 |
| User and groups | 40 |
| Runtime | 25 |
| TrollStore | 15 |
| Visibility and detector privileges | 0 |

The filesystem groups' correlation discount is recorded as `correlationDiscount`. Displayed group deductions can therefore sum to more than the final deduction.

### Ratings

| Rating | Condition |
| :--- | :--- |
| Perfect | Score 100 and every enabled check is conclusive |
| Suspected | Risk 1–29, or score 71–99; also any unknown checks, potentially with score 100 |
| Abnormal environment | Risk at least 30, or score 0–70 |

### Common evidence weights

| Evidence | Weight |
| :--- | ---: |
| Jailbreak-specific path | Usually 35 |
| `/var/jb`, `/bin/bash` or `/taurine` alone | 20 |
| Randomized `.jbroot-*` name | 15 |
| Randomized `.jbroot-*` with dpkg/basebin corroboration | 40 |
| Environment tool registration | 15 |
| Public tool URL | 10 |
| Injection library, related function origin or jailbreak service | 35 |
| Kernel/libc file visibility contradiction | 10 |
| Root identity or supplementary wheel/daemon group | 40 |
| Other non-mobile identity, identity mismatch or admin group | 20 |
| DYLD injection variables or writable root mount | 20 |
| TrollStore path or URL handler | 12, subject to the TrollStore group cap of 15 |

Only `hit` findings deduct points. Insufficient permissions or interface errors are `unknown`. Disabled extended checks are `skipped`, not passed. The score is a transparent heuristic, not a statistical probability.

## Visibility limits

Shadow can filter paths, URLs, processes and system calls. Choicy can disable injection. The absence of visible injected libraries does not establish that a device is not jailbroken. RootHide or other hooks may spoof local queries; directories may be leftovers and tool variants may be renamed.

An unsigned IPA cannot embed active signed entitlements. Read access depends on installer configuration. The private API switch grants no additional privileges. `Sources/Entitlements.plist` is a reference only and is not used for signing or packaging.

Perfect means only that the currently enabled, visible checks found no evidence or errors. The simulator validates launch, UI, settings and reports; physical-device checks are always unknown with zero weight there. The current version has not been physically tested on the iPhone XR/iOS 14.8/Taurine/Shadow + Choicy combination.

## Sources

| Source | Purpose |
| :--- | :--- |
| [Taurine](https://github.com/Odyssey-Team/Taurine) | libhooker, bootstrap paths and services |
| [Dopamine](https://github.com/opa334/Dopamine) | Rootless bootstrap paths |
| [ElleKit packaging](https://github.com/tealbathingsuit/ellekit/blob/main/Makefile) | Injection components and compatibility links |
| [RootHide developer guide](https://github.com/RootHide/Developer/blob/main/roothide.md) | Randomized jbroot and path layout |
| [Relaxin source snapshot](https://github.com/xz1c/relaxin) | Variant identifiers and bootstrap layout |
| [TrollStore](https://github.com/opa334/TrollStore#unsandboxing) | Installation markers and privilege limitations |
| [LaunchServices headers](https://github.com/theos/headers/blob/master/MobileCoreServices/LSApplicationWorkspace.h) | URL handler interfaces |
| [Shadow](https://github.com/jjolano/shadow) | Query and syscall filtering |
| [Apple XNU calling convention](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/custom/SYS.h) | ARM64 syscall entry point |
| [DeviceKit identifier mapping](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift) | Device model mapping |
