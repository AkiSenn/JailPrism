# 环境哨兵 / IOSGuard 1.1.0

原生 UIKit 本地环境检测器，最低 iOS 14.0，IPA 包含 arm64 与 arm64e。Windows 生成工程，GitHub Actions macOS runner 编译。交付完全未签名 IPA：不含 ad-hoc 签名、签名资源、描述文件或内嵌 entitlement。TrollStore 安装后的权限和可安装系统范围由安装器决定。

## 使用与设置

下载 Actions 构建产物中的 `IOSGuard-unsigned.ipa`，通过 TrollStore 安装。主页顶部显示具体 iPhone 型号、硬件标识、iOS 版本及构建号、检测完成时间（含时区）、耗时、环境评分和疑似越狱类型。右上角分享按钮导出 JSON 原始证据；齿轮进入二级设置页。

- 语言：跟随系统（默认）、English `en_US`、简体中文 `zh_Hans_CN`。系统简体与繁体中文（含中国大陆、台湾、香港地区）统一使用简体资源；其他语言回退英语。返回主页自动按设置重新检测。
- 使用私有 API：默认关闭，持久保存选择。开启后尝试全面只读检测，包括巨魔 URL 实际处理者、工具注册、随机引导目录、检测器权限、沙盒策略、越狱守护进程、Mach 服务和 ARM64 内核读取。供证书或巨魔安装用户选择；开关不授予权限，也不能保证绕过隐藏插件。
- 私有模式关闭时上述扩展检测和原始 SVC 均不调用。跳过项标记 `skipped`，不冒充「未命中」。公开 URL 查询只调用 canOpenURL，从不打开或触发安装。

应用不联网；报告仅在用户主动分享时导出。不执行提权、越狱、其他进程注入、安装、删除、系统写入或 Mach 服务消息发送。

## 分类与评分

分类与评分分别计算。命中有根、无根、隐根证据显示「疑似有根越狱（rootful）」「疑似无根越狱（rootless）」「疑似隐根越狱（roothide）」。多种证据并存时保留多个疑似类型，并导出对应检测 ID。只发现工具或通用注入时不强行推断类型；只有巨魔不会判定越狱。Dopamine 普通版与 RootHide 版可能共享 bundle ID，需结合真实路径、`.jbroot` 或服务等证据区分。工具安装和历史残留不能证明当前已激活越狱。

基础 100 分，唯一检测 ID 去重；风险为命中证据的加权扣分。rootful/rootless/roothide 每组上限 45，三组合计仍最多 45；注入 35、用户组 40、运行环境 25、巨魔 15；可见性与检测器自身权限 0。总扣分最高 100。`correlationDiscount` 记录文件系统组的关联抵扣。

| 评级 | 规则 |
|---|---|
| 完美 | 100 分且启用检测没有不可判定项 |
| 疑似 | 风险 1–29（71–99 分），或存在不可判定项，可为 100 分 |
| 异常环境 | 风险至少 30（0–70 分） |

越狱专用路径通常 35 分；单独 `/var/jb`、`/bin/bash`、`/taurine` 为 20；随机 `.jbroot-*` 名称 15，有 dpkg/basebin 佐证 40；工具注册 15，公开工具 URL 10；注入与越狱服务 35，内核/用户态可见性矛盾 10；root 身份或 wheel/daemon 附加组 40，其他非 mobile 身份、身份差异、admin 组 20；DYLD 变量和可写根挂载 20；巨魔路径/处理者 12，合计上限 15。权限不足和接口错误标记不可判定，不虚构风险或通过。评分是启发式规则，不是统计概率。

## 检测范围

- Taurine / rootful：libhooker、libblackjack、TweakInject、`/taurine/jailbreakd`、amfidebilitate、pspawn、`org.coolstar.jailbreakd` 等。Taurine 不依赖 Substitute；保留 Substitute 路径以覆盖 unc0ver，以及 MobileSubstrate、apt/dpkg、历史引导标记。
- Dopamine / rootless：`/var/jb`、basebin、libjailbreak、ElleKit 和实际 Preboot 的 `dopamine-*` / `jb-*` 下 procursus 路径。
- ElleKit：rootful/rootless 的 libellekit、libinjector、pspawn、loader、TweakInject/TweakLoader 与兼容符号链接；已加载镜像和函数来源也检查 ElleKit。RootHide 路径中的 ElleKit归入隐根证据。
- Dopamine RootHide / Relaxin：自身及工具 bundle 的 `.jbroot`，Bundle Application/Shared AppGroup 的 `.jbroot-*`，dpkg/basebin 佐证、libroothide、注入路径；已知 Relaxin/RelaxinLite 注册 ID。改名变体可能无法按 ID 识别。
- TrollStore：本 App 与可读取容器的 `_TrollStore` / `_TrollStoreLite`、工具目录和注册 ID。私有 URL 处理者严格匹配 `com.opa334.TrollStore` / `TrollStoreLite`；苹果 Magnifier 本身不作为巨魔证据。
- 每条路径交叉比较 lstat/stat/access/只读 open/FileManager；私有模式真机再比较只读 ARM64 SVC。原始入口只接受路径，固定只读，无创建或写入能力。内核阳性且 libc lstat/open 同时报告不存在时提示过滤或状态变化；不会把该矛盾直接宣称为成功绕过 Shadow。
- UID/EUID/GID/EGID、组名称和成员关系；dyld 镜像、公有函数 dladdr 来源、DYLD 变量、根挂载。arm64e 函数地址先去除 PAC 再交给 dladdr，不手工解引用代码指针。

「用户组异常行为」指检测器进程相对 mobile（501）基线的身份/权限异常，不是系统历史审计。正常系统账户的存在不算异常，未知组名本身也不算越狱。

## 构建与验证

`python scripts/generate_project.py` 生成无依赖 Xcode 工程；macOS 执行 `bash scripts/build.sh`。CI 校验 100 个双语资源的键与格式占位符，运行评分、URL、类型判定、语言映射和默认私有开关回归。验证设备双架构、最低 iOS、每个 Mach-O 切片无 `LC_CODE_SIGNATURE`、无签名资源和描述文件，再在模拟器检查默认英语、繁体映射简体、手动语言覆盖与开启私有模式的报告及设置页。`scanConfiguration.privateOperationsAttempted` 可审核模式开关是否实际执行扩展项。

模拟器所有真机环境检测项均不可判定、权重 0，不把宿主用户组或 shell 当成 iOS 越狱。模拟器验证启动、设置、翻译、报告和开关；不能验证真机准确率。尚未在用户的 iPhone XR iOS 14.8 / Taurine / Shadow + Choicy 上实测。

图标使用用户图片白底版本 `Artwork/AppIcon-white.png`；全部图标尺寸已打包。`Sources/Entitlements.plist` 仅为参考，不参与签名或打包。

## 依据与限制

- [Taurine](https://github.com/Odyssey-Team/Taurine)：libhooker、Taurine 引导路径与服务。
- [Dopamine](https://github.com/opa334/Dopamine)、[ElleKit 打包源码](https://github.com/tealbathingsuit/ellekit/blob/main/Makefile)：普通无根路径、实际注入组件和兼容链接。
- [RootHide 文档](https://github.com/RootHide/Developer/blob/main/roothide.md)、[Relaxin 源码快照](https://github.com/xz1c/relaxin)：随机 jbroot 和变体标识。
- [TrollStore](https://github.com/opa334/TrollStore#unsandboxing)、[LaunchServices 头文件](https://github.com/theos/headers/blob/master/MobileCoreServices/LSApplicationWorkspace.h)：安装标记、实际 URL 处理者及权限限制。
- [Shadow 源码](https://github.com/jjolano/shadow)：路径、进程、URL 和系统调用过滤；原始 SVC 也可能被处理。
- [Apple XNU 调用约定](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/custom/SYS.h)、[设备标识映射](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift)。

Shadow 可隐藏查询结果，Choicy 可关闭注入；未见注入不表示未越狱。无签名包无法预置生效权限，读取能力受安装器配置影响。RootHide 或其他 hook 可伪造本地查询，目录可能是残留，变体可改名。未命中不等于不存在，「完美」仅表示已启用的当前可见范围没有证据或错误。
