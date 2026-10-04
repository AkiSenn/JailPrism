<div align="center">

<img src="Artwork/AppIcon-white.png" width="112" alt="IOSGuard 应用图标">

# IOSGuard · 环境哨兵

**查看 iPhone 环境，用证据解释每一次判定。**

原生 iOS 环境检测工具，支持越狱类型识别、透明评分与本地报告导出。

![iOS](https://img.shields.io/badge/iOS-14.0%2B-007AFF?style=flat-square)
![Architecture](https://img.shields.io/badge/Architecture-arm64%20%7C%20arm64e-555555?style=flat-square)
![Objective-C](https://img.shields.io/badge/Language-Objective--C-438EFF?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.1.0-00A896?style=flat-square)

[下载构建](https://github.com/AkiSenn/IOSGuard/actions/workflows/build.yml) · [使用指南](docs/USAGE.md) · [检测原理](docs/DETECTION.md) · [更新记录](CHANGELOG.md) · [问题反馈](https://github.com/AkiSenn/IOSGuard/issues)

</div>

## 项目介绍

IOSGuard 在设备上检查可见的文件、URL、注入库、进程身份与运行环境，显示疑似越狱类型和对应证据。检测结果分为「完美」「疑似」「异常环境」，每项检查的状态、权重及评分依据都可查看。

应用使用 UIKit 与 Objective-C 实现，无第三方代码依赖。检测在本地运行，应用不联网；JSON 报告由用户主动分享导出。

## 界面预览

<table>
  <tr>
    <th>检测结果</th>
    <th>语言与检测设置</th>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/results.png" width="260" alt="中文检测结果：设备信息、检测时间、评分与证据列表"></td>
    <td align="center"><img src="docs/images/settings.png" width="260" alt="二级设置：语言选择与私有 API 开关"></td>
  </tr>
</table>

截图来自模拟器，用于展示界面。模拟器中的真机检测项显示「不可判定」，不代表真实设备检测结果。

## 主要功能

| 功能 | 内容 |
| :--- | :--- |
| 设备概览 | 具体 iPhone 型号、硬件标识、iOS 版本、构建号、检测时间与耗时 |
| 越狱类型 | 根据证据显示疑似 rootful、rootless、roothide；支持多种类型同时展示 |
| 注入框架 | 覆盖 libhooker、Substitute、MobileSubstrate 与 ElleKit 相关特征 |
| 巨魔检测 | 安装标记、工具注册与 URL 处理者；苹果放大镜本身不作为巨魔证据 |
| 身份检查 | UID／GID、有效身份与附加用户组异常 |
| 扩展检测 | 私有 API 开关默认关闭，开启后尝试更多只读检测 |
| 双语界面 | 自动选择语言，支持手动切换 English 或简体中文 |
| 报告导出 | JSON 包含检查证据、评分贡献、疑似类型与本次检测配置 |

覆盖的特征包括 Taurine、unc0ver、Dopamine、Dopamine RootHide、Relaxin／RelaxinLite 与 TrollStore。具体检测项与可见性限制见[检测原理](docs/DETECTION.md)。

## 下载与安装

1. 打开 [GitHub Actions 构建页面](https://github.com/AkiSenn/IOSGuard/actions/workflows/build.yml)，选择成功完成的运行。
2. 下载 **Artifacts** 中的 `IOSGuard-unsigned-iOS14-arm64-arm64e`。
3. 解压 ZIP，找到 `IOSGuard-unsigned.ipa`，通过 TrollStore 安装。
4. 启动应用自动检测；点击右上角齿轮调整语言与私有 API 设置。

| 项目 | 要求 |
| :--- | :--- |
| 最低系统 | iOS 14.0 |
| 设备架构 | arm64、arm64e |
| 分发文件 | 完全未签名 IPA，无 ad-hoc 签名、描述文件或内嵌 entitlement |
| 安装方式 | TrollStore；其支持的系统范围和安装权限由安装器决定 |

构建产物保留 30 天。下载 Actions 产物需要登录有仓库访问权限的 GitHub 账户；过期后可重新构建。完整操作说明见[使用指南](docs/USAGE.md)。

## 如何理解结果

| 评级 | 条件 |
| :--- | :--- |
| **完美** | 100 分，且已启用检查没有不可判定项 |
| **疑似** | 71–99 分，或存在不可判定项；因此也可能显示 100 分 |
| **异常环境** | 0–70 分 |

评分与越狱类型分别计算。巨魔证据单独最多扣 15 分，不等同于越狱；安装工具或残留目录也不代表越狱正在运行。未启用的私有检测显示「已跳过」，读取受限的项目显示「不可判定」。

Shadow、Choicy 和其他隐藏机制可能影响检测可见性。「完美」表示当前已启用的可见检查没有证据或错误，不能证明设备绝对未越狱。私有 API 开关不会授予额外权限。详见[评分规则与限制](docs/DETECTION.md#评分机制)。

## 开发与文档

| 文档 | 内容 |
| :--- | :--- |
| [使用指南](docs/USAGE.md) | 安装、语言、私有模式、筛选与报告导出 |
| [检测原理](docs/DETECTION.md) | 环境特征、证据分类、评分机制与参考来源 |
| [构建说明](docs/BUILDING.md) | Windows 工程生成、GitHub 云编译、macOS 构建与验证 |
| [贡献与反馈](CONTRIBUTING.md) | 复现信息、漏检反馈与代码修改约定 |
| [更新记录](CHANGELOG.md) | 各版本的功能变化 |

在 macOS 上构建：

```bash
bash scripts/build.sh
```

Windows 用户可通过 GitHub Actions 编译，无需在本机安装 Xcode。CI 会验证评分与设置回归、语言资源、双架构未签名包，以及模拟器中的语言切换和模式开关；真机准确率需要安装实测。
