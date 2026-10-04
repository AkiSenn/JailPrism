# 检测原理

[返回项目首页](../README.md) · [使用指南](USAGE.md) · [构建说明](BUILDING.md)

[English](en/DETECTION.md)

## 环境覆盖

| 环境／框架 | 主要证据 |
| :--- | :--- |
| Taurine · rootful | libhooker、libblackjack、TweakInject、`/taurine/jailbreakd`、amfidebilitate、pspawn、`org.coolstar.jailbreakd` |
| unc0ver · rootful | Substitute、Cydia、apt／dpkg、历史引导标记 |
| MobileSubstrate | 注入目录、相关库与已加载镜像 |
| Dopamine · rootless | `/var/jb`、basebin、libjailbreak、ElleKit，以及 Preboot 中 `dopamine-*`／`jb-*` 下的 procursus 路径 |
| Dopamine RootHide、Relaxin／RelaxinLite | `.jbroot` 链接、随机 `.jbroot-*` 目录、dpkg／basebin 佐证、libroothide、注入路径与已知注册 ID |
| ElleKit | libellekit、libinjector、pspawn、loader、TweakInject／TweakLoader、兼容符号链接与已加载镜像 |
| TrollStore／TrollStoreLite | `_TrollStore`／`_TrollStoreLite` 标记、工具目录、注册 ID 与 URL 实际处理者 |

Taurine 使用 libhooker；Substitute 特征用于覆盖 unc0ver 等环境。ElleKit 同时覆盖 rootful 与 rootless 路径，位于 RootHide 路径中的证据归入 roothide。

工具注册、随机目录和额外服务查询需要开启私有 API 模式。已知 ID 覆盖不等于覆盖所有改名变体。

## 检测方法

### 文件交叉查询

同一路径通过 `lstat`、`stat`、`access`、只读 `open` 和 `FileManager` 比较。路径项导出各通道的状态及可取得的 errno；可读取的文件属性包含拥有者、权限和符号链接目标。

扩展模式在 ARM64 真机上增加只读 SVC 入口。入口仅接受路径，固定只读，没有创建或写入能力。当内核读取成功，而 libc 的 `lstat` 与 `open` 同时报不存在时，提示可能的过滤或文件系统状态变化。

原始 SVC 也可能被拦截。查询矛盾是证据，不等于已成功绕过 Shadow。

### URL 与工具注册

标准模式查询公开 `canOpenURL` 可用性。扩展模式通过 LaunchServices 查询实际 URL 处理者及相关工具注册信息。

巨魔处理者严格匹配 `com.opa334.TrollStore` 或 `com.opa334.TrollStoreLite`；系统 `com.apple.Magnifier` 本身不作为巨魔证据。检测只查询，不打开 URL，也不触发安装。

### 身份与运行环境

- 当前进程 UID／EUID／GID／EGID、用户组名称和成员关系。
- dyld 镜像与公有函数的 `dladdr` 来源。
- DYLD 注入环境变量与根文件系统挂载状态。
- 扩展模式下的权限、沙盒读取策略、已知越狱守护进程与 Mach 服务查询。

arm64e 函数地址先去除 PAC，再交给 `dladdr`；不手工解引用代码指针。进程枚举只保留已知越狱守护进程的匹配信息；Mach 服务只查找端口，不发送消息。

## 类型判定

分类与评分分别计算。命中证据根据实际路径、检测分组或明确的类型提示，展示以下疑似结论：

| 类型 | 显示结论 |
| :--- | :--- |
| `rootful` | 疑似有根越狱（rootful） |
| `rootless` | 疑似无根越狱（rootless） |
| `roothide` | 疑似隐根越狱（roothide） |

多类证据并存时保留多个类型，报告记录各类型的证据 ID。只有巨魔不判为越狱；只有通用注入证据时，类型可以保持未确定。

Dopamine 普通版与 RootHide 版可能共享 bundle ID，不能只凭名称区分。Sileo、Zebra 的安装也不能直接推断为 rootless。已安装工具和残留目录均不证明当前越狱正在运行。

## 评分机制

基础 100 分。按唯一检测 ID 去重后计算命中项扣分，再应用分组上限。总扣分最多 100 分。

| 证据分组 | 扣分上限 |
| :--- | ---: |
| rootful／rootless／roothide | 每组 45，三组合计仍最多 45 |
| 注入与过滤 | 35 |
| 用户与用户组 | 40 |
| 运行环境 | 25 |
| 巨魔 | 15 |
| 可见性与检测器自身权限 | 0 |

文件系统三组的关联抵扣记录在 `correlationDiscount` 中，因此展示的各组扣分相加可能高于最终扣分。

### 评级规则

| 评级 | 条件 |
| :--- | :--- |
| 完美 | 100 分，且启用项均可判定 |
| 疑似 | 风险 1–29，即 71–99 分；或存在不可判定项，可为 100 分 |
| 异常环境 | 风险至少 30，即 0–70 分 |

### 常见证据权重

| 证据 | 权重 |
| :--- | ---: |
| 越狱专用路径 | 通常 35 |
| 单独 `/var/jb`、`/bin/bash`、`/taurine` | 20 |
| 随机 `.jbroot-*` 名称 | 15 |
| 随机 `.jbroot-*` 有 dpkg／basebin 佐证 | 40 |
| 环境工具注册 | 15 |
| 公开工具 URL | 10 |
| 注入库、相关函数来源或越狱服务 | 35 |
| 内核与 libc 文件可见性矛盾 | 10 |
| root 身份、wheel／daemon 附加组 | 40 |
| 其他非 mobile 身份、身份差异、admin 组 | 20 |
| DYLD 注入变量、可写根挂载 | 20 |
| 巨魔路径或 URL 处理者 | 12，巨魔分组总上限为 15 |

仅 `hit` 状态参与扣分。权限不足和接口错误记为 `unknown`；关闭的扩展检测记为 `skipped`，不当作已通过。评分是透明的启发式规则，不是统计概率。

## 可见性限制

Shadow 可过滤路径、URL、进程及系统调用；Choicy 可关闭注入。没有可见注入库，不代表设备未越狱。RootHide 或其他 hook 可伪造本地查询，目录可能是历史残留，工具变体也可能改名。

未签名 IPA 无法预置生效 entitlement，读取能力取决于安装器配置。私有 API 开关不会授予额外权限。`Sources/Entitlements.plist` 仅作参考，不参与签名或打包。

「完美」只表示当前已启用的可见检查没有证据或错误。模拟器只能验证启动、界面、设置与报告；真机检测项在模拟器中统一不可判定、权重为 0。当前版本尚未在 iPhone XR、iOS 14.8、Taurine、Shadow + Choicy 的组合上实测。

## 参考来源

| 来源 | 用途 |
| :--- | :--- |
| [Taurine](https://github.com/Odyssey-Team/Taurine) | libhooker、引导路径与服务 |
| [Dopamine](https://github.com/opa334/Dopamine) | 无根引导路径 |
| [ElleKit 打包源码](https://github.com/tealbathingsuit/ellekit/blob/main/Makefile) | 注入组件与兼容链接 |
| [RootHide 开发文档](https://github.com/RootHide/Developer/blob/main/roothide.md) | 随机 jbroot 与路径布局 |
| [Relaxin 源码快照](https://github.com/xz1c/relaxin) | 变体标识与引导布局 |
| [TrollStore](https://github.com/opa334/TrollStore#unsandboxing) | 安装标记与权限限制 |
| [LaunchServices 头文件](https://github.com/theos/headers/blob/master/MobileCoreServices/LSApplicationWorkspace.h) | URL 处理者接口 |
| [Shadow](https://github.com/jjolano/shadow) | 查询与系统调用过滤 |
| [Apple XNU 调用约定](https://github.com/apple-oss-distributions/xnu/blob/main/libsyscall/custom/SYS.h) | ARM64 系统调用入口 |
| [DeviceKit 标识映射](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift) | 设备型号映射 |
