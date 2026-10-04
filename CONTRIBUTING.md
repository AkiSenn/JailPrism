# 贡献与反馈

[返回项目首页](README.md) · [构建说明](docs/BUILDING.md)

## 反馈漏检、误报或崩溃

请在 [Issues](https://github.com/AkiSenn/JailPrism/issues) 中说明复现步骤，并提供以下信息：

| 信息 | 示例 |
| :--- | :--- |
| 应用版本 | 1.2.0 |
| 设备与系统 | iPhone XR / iOS 14.8 |
| 越狱工具与版本 | Taurine、unc0ver、Dopamine 或 RootHide 变体 |
| 安装方式 | TrollStore 或证书安装 |
| 隐藏与注入配置 | Shadow、Choicy、是否允许向检测器注入 |
| 私有 API | 开启或关闭 |
| 专业用户模式 | 开启或关闭 |
| 预期与实际结果 | 预期识别的类型、实际评分及命中项 |
| 检测报告 | 对应本次结果的 `JailPrism-report.json` |

复现界面问题时补充语言选择与截图。报告中的路径和身份信息可按需移除无关内容；保留涉及误报或漏检的检测 ID、状态与通道结果，方便定位。

## 修改代码

1. 围绕一个明确问题提交修改，说明修改后的行为和验证结果。
2. 新增检测证据时记录来源、适用环境、权重与可见性限制。
3. 不把权限拒绝、接口不可用或跳过项目当作已通过。
4. 新增私有接口放在开关控制的扩展检测中，保持默认关闭。
5. 用户可见文本同时添加 `en_US` 与 `zh_Hans_CN` 资源。
6. 新增源文件或资源后重新运行工程生成脚本。

评分、类型判定或语言逻辑的行为变化，应补充有意义的回归检查。文档和截图修改只需核对链接、显示效果及说明是否与实现一致。

## 验证

语言资源检查可在 Windows 或 macOS 执行：

```bash
python scripts/check_localizations.py
```

macOS 执行完整构建：

```bash
bash scripts/build.sh
```

Windows 用户可在 GitHub Actions 点击 **Run workflow** 并选择待验证分支。设备包应保持双架构、最低 iOS 14.0 和完全未签名。
