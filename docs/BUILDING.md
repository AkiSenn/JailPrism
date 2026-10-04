# 构建说明

[返回项目首页](../README.md) · [使用指南](USAGE.md) · [检测原理](DETECTION.md)

[English](en/BUILDING.md)

## 项目结构

```text
JailPrism/
├── Sources/                  # UIKit 界面、检测、评分、设置与语言资源
├── Tests/                    # Foundation 回归检查
├── scripts/                  # 工程生成、构建、校验与模拟器检查
├── JailPrism.xcodeproj/       # 由脚本生成的 Xcode 工程
├── Artwork/                  # 白底应用图标原图
├── docs/                     # 使用与技术文档
└── .github/workflows/        # GitHub Actions 云编译
```

原生 Objective-C／UIKit，无第三方代码依赖。设备构建最低 iOS 14.0，架构为 arm64 与 arm64e；Bundle ID 为 `com.akisenn.JailPrism`。

## GitHub Actions 云编译

Windows 用户可以直接使用 [Build unsigned JailPrism IPA](https://github.com/AkiSenn/JailPrism/actions/workflows/build.yml)：

1. 打开 workflow 页面。
2. 点击 **Run workflow**，选择 `main`。
3. 等待运行成功，下载 `JailPrism-unsigned-iOS14-arm64-arm64e`。

向 `main` 推送提交也会触发构建。Runner 使用 `macos-15`，构建产物保留 30 天。

| 产物 | 内容 |
| :--- | :--- |
| `JailPrism-unsigned.ipa` | 双架构未签名设备包 |
| `build-metadata.json` | 架构、系统下限、版本与未签名校验结果 |
| `SHA256SUMS.txt` | IPA 的 SHA-256 |
| `simulator-*.png` | 结果页与设置页截图 |
| `simulator-*-report.json` | 各语言／模式场景的报告 |
| `simulator-smoke.txt` | 模拟器检查结果 |
| `*build.log` | 设备和模拟器编译日志 |

失败的运行也会上传已生成的日志或产物。下载可安装包时应选择**整体运行成功**的构建。

## GitHub Releases

已验证的构建也可发布到 [Releases](https://github.com/AkiSenn/JailPrism/releases)，直接提供版本化的未签名 IPA、匹配该文件名的 `SHA256SUMS.txt`、`build-metadata.json` 和模拟器检查结果。发行版附件不受 Actions 的 30 天保留期限影响。

创建发行版时先核对版本、双架构、未签名状态与 SHA-256；附件应来自成功完成的云编译。若版本标签包含后续文档提交，应确认应用源代码和构建配置与已验证的构建提交一致。当前构建 workflow 上传 Actions 产物；发行版由维护者单独发布。

## 本地生成工程

Windows 或 macOS 安装 Python 3 后，在仓库根目录执行：

```bash
python scripts/generate_project.py
```

脚本生成 `JailPrism.xcodeproj`。新增源文件或语言目录后重新生成工程；直接修改生成的工程可能被下一次生成覆盖。

## macOS 本地构建

准备 Xcode、iOS SDK、Python 3 与已配置的 Xcode 命令行工具，然后执行：

```bash
bash scripts/build.sh
```

输出文件位于 `dist/JailPrism-unsigned.ipa`。构建脚本关闭 Xcode 签名，并禁止设备链接器生成 ad-hoc 签名，不调用签名工具。

可独立执行语言资源检查：

```bash
python scripts/check_localizations.py
```

## CI 验证内容

| 检查 | 验证内容 |
| :--- | :--- |
| 语言资源 | 两种资源的键与格式占位符一致 |
| 评分与设置回归 | URL 分类、评分上限、类型证据、名称去重、语言映射、专业／私有开关默认关闭及偏好保留 |
| 设备包 | arm64／arm64e、最低 iOS 14.0、两个切片均无 `LC_CODE_SIGNATURE` |
| 签名资源 | 无 `_CodeSignature`、描述文件及内嵌 entitlement |
| 模拟器 | 语言、普通／专业主页、扩展模式、中英文设置页、名称换行示例 |

模拟器检查确认应用进程存活，并验证报告结构、设备信息、时间字段和模式开关。`scanConfiguration.privateOperationsAttempted` 在标准模式为空，扩展模式记录已尝试的操作。

模拟器无法验证真机越狱准确率。发布前的设备实测应记录系统、越狱工具、隐藏插件、安装方式与对应 JSON 报告。

名称换行预览使用 `previewFixture: true` 标识的示例报告，只响应模拟器测试参数。示例入口通过 `TARGET_OS_SIMULATOR` 限定，不包含在设备 IPA 中。
