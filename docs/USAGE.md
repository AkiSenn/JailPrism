# 使用指南

[返回项目首页](../README.md) · [检测原理](DETECTION.md) · [构建说明](BUILDING.md)

[English](en/USAGE.md)

## 安装

1. 打开 [GitHub Releases](https://github.com/AkiSenn/JailPrism/releases/latest)。
2. 直接下载 Assets 中的 `JailPrism-<版本>-unsigned.ipa`，可用同页的 `SHA256SUMS.txt` 核对完整性。
3. 将 IPA 分享给 TrollStore 安装。

如需最新开发构建，也可在 [GitHub Actions](https://github.com/AkiSenn/JailPrism/actions/workflows/build.yml) 选择整体成功的运行，下载 `JailPrism-unsigned-iOS14-arm64-arm64e` ZIP，解压后安装 `JailPrism-unsigned.ipa`。

应用最低支持 iOS 14.0，IPA 包含 arm64 与 arm64e。应用支持范围与 TrollStore 可安装范围分别由应用和安装器决定；并非所有 iOS 14+ 系统都支持 TrollStore。

交付 IPA 完全未签名，不含 ad-hoc 签名、签名资源、描述文件或内嵌 entitlement。安装后的运行权限取决于安装器配置。

## 查看检测结果

启动应用会自动检测。主页顶部依次显示设备型号、硬件标识、iOS 版本与构建号、检测完成时间（含时区）、检测耗时、评分和疑似越狱类型。点击左上角「重新检测」刷新结果。

专业模式提供以下筛选；普通模式不显示该控件。

| 筛选 | 显示内容 |
| :--- | :--- |
| 全部 | 本次检测的所有项目 |
| 命中 | 检测到特征的项目 |
| 不确定 | 权限受限、接口不可用或其他无法判定的项目 |
| 用户组 | 当前检测器进程的用户、主组与附加组检查 |

普通模式默认显示设备信息、评分与疑似环境，底部不显示技术注释。巨魔命中时显示「检测出TrollStore巨魔」，越狱显示具体类型，如 Rootless（无根越狱）。

商店和注入动态库分别以名称列表展示，重复名称合并；后续行与首行名称对齐。例如：

```text
检测出Cydia
      Sileo

检测出Choicy.dylib
      ShadowCore.dylib
```

真实界面通过布局对齐，不依赖固定空格。动态库列表来自已加载镜像或函数来源中的已知注入特征，不把文件存在直接当成已加载，也不提供签名合法性鉴定。

## 专业用户模式

打开 **齿轮 → 显示模式 → 专业用户模式**。默认关闭，选择会保存。开启后主页显示全部检测项、路径、权重、评分规则、状态和技术说明，并可使用下方筛选。切换展示模式复用本次报告，不自动启用私有 API，也不会改变评分。

每个检测项展示状态、权重与证据。单项权重不是最终扣分，分组上限和关联抵扣会影响实际评分，见[评分机制](DETECTION.md#评分机制)。

「用户组异常」记录当前检测器进程相对 mobile（501）基线的身份偏差，不是系统行为历史或其他应用的身份审计。正常系统账户的存在不算异常。

## 语言设置

打开右上角 **齿轮 → 语言**：

| 选项 | 行为 |
| :--- | :--- |
| 跟随系统 | 默认选项；简体和繁体中文统一使用 `zh_Hans_CN`，其他语言使用 `en_US` |
| English | 固定使用 `en_US` 英文界面 |
| 简体中文 | 固定使用 `zh_Hans_CN` 简体中文界面 |

系统繁体中文地区（包括台湾、香港）也显示简体中文。选择会保存，返回主页后自动按新设置重新检测。

## 私有 API 设置

打开 **齿轮 → 扩展环境检测 → 使用私有 API**。开关默认关闭，用户选择会保存。

| 模式 | 检测范围 |
| :--- | :--- |
| 标准检测 | 公开文件与 URL 查询、进程身份、dyld 镜像、函数来源及运行环境 |
| 扩展检测 | 标准检测，加上私有 URL 处理者、工具注册、随机引导目录、权限与沙盒查询、守护进程、Mach 服务和只读 ARM64 内核探测 |

供企业内部分发（In-House）或 TrollStore 安装用户选择。英文使用 Apple 的 [In-House (Enterprise) distribution](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles) 称呼，中文对应[企业内部分发](https://developer.apple.com/cn/business/get-started/)。开启开关不会授予额外权限，也不能保证绕过 Shadow、Choicy 或 RootHide 的隐藏机制。

关闭时扩展项与原始 SVC 均不调用，相关项显示「已跳过」。权限不足或私有接口不可用时显示「不可判定」。两种状态都不会被当作「未命中」。

## 导出报告

点击右上角 **分享按钮**，保存或分享 `JailPrism-report.json`。

| 字段 | 内容 |
| :--- | :--- |
| `device` | 型号、硬件标识、iOS 版本、构建号、执行架构与模拟器标识 |
| `scanTime` / `scanDuration` | 检测完成时间与耗时 |
| `scanConfiguration` | 本次模式、私有 API 开关状态、尝试过的扩展操作 |
| `identity` | 当前进程 UID／GID、有效身份与附加组 |
| `score` | 评分、分组扣分、关联抵扣及各证据的实际贡献 |
| `classification` | 疑似类型、类型证据 ID 与巨魔识别状态 |
| `findings` | 每项状态、权重、证据；路径项还包含交叉查询通道 |
| `simpleSummary` | 普通模式的分类名称列表与对应证据 ID |
| `presentationMode` | 导出时的普通／专业展示模式 |

报告结构版本为 `schema: 2`。`scanConfiguration.privateOperationsAttempted` 可用于确认扩展检测是否实际调用。

应用不联网，报告仅在主动分享时导出。检测不执行提权、越狱、其他进程注入、安装、删除、系统写入、URL 打开或 Mach 服务消息发送。

## 结果异常或漏检

记录系统版本、设备型号、越狱工具、安装方式、隐藏插件与私有 API 开关状态，并导出本次 JSON 报告。反馈方式见[贡献与反馈](../CONTRIBUTING.md)。

模拟器的真机检查项统一显示不可判定、权重为 0；模拟器结果不能用于判断真实设备是否越狱。

## 致谢与项目说明

AI 生成说明及 Codex、GPT-6.1 Sol 的致谢只保留在[项目首页](../README.md)，不在应用设置页显示。语言列表下方不显示系统语言映射说明；自动选择语言的行为保持一致。
