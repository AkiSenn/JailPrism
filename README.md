# 环境哨兵 / IOSGuard

中文、本地运行的 iOS 环境检测器。最低 iOS 14.0，设备 IPA 包含 arm64 和 arm64e 两个 Mach-O 切片；iPhone XR 等 arm64e 设备亦可运行 arm64 切片。使用 GitHub Actions 的 macOS runner 编译，Windows 不需要 Xcode。通过 TrollStore 安装 IPA；该分发方式的系统版本支持范围由 TrollStore 决定，并非所有 iOS 14+ 都能通过 TrollStore 安装。

## 使用

下载 Actions 的 `IOSGuard-unsigned-iOS14-arm64-arm64e` 构建产物，解压后将 `IOSGuard-unsigned.ipa` 分享给 TrollStore 安装。交付 IPA 完全未签名，无签名资源、描述文件和内嵌 entitlement。启动自动检测，点击「重新检测」刷新；筛选全部、命中、不可判定、用户组。右上角分享按钮导出 JSON 报告，包含原始证据、权重、分组扣分、关联抵扣、当前身份与检测限制。App 没有网络请求；报告只在主动分享时离开设备。

「用户组异常行为」在本版本指当前检测器进程的 root/非 mobile 身份、真实与有效 UID/GID 差异、wheel/root、daemon、admin 附加组，以及命中文件的拥有者；不是系统行为历史或其他应用的身份审计。正常的 root/mobile 账户存在不算异常。不执行提权、安装、删除、写入系统目录、打开巨魔安装 URL 或修改系统配置。

## 评分 v1

基础 100 分，风险 = 命中证据的加权扣分。按唯一检测 ID 去重，再施加分组上限：rootful/rootless/roothide 每组 45，三组共同不超过 45；注入 35，用户组 40，运行环境 25，巨魔 15；检测可见性与检测器自身权限 0。总扣分最高 100。报告记录三组共同上限带来的 `correlationDiscount`，因此各组展示值相加可能高于最终扣分。

| 评级 | 规则 |
|---|---|
| 完美 | 100 分，且没有不可判定项；表示当前检测范围通过 |
| 疑似 | 风险 1–29（71–99 分），或任意不可判定项；可为 100 分 |
| 异常环境 | 风险至少 30（0–70 分） |

独立显示越狱痕迹结论。TrollStore-only 最多扣 15 分，评级为疑似，不声明已越狱。工具 App 注册证据通常 15 分，不能说明当前已激活越狱；越狱专用路径通常 35 分；单独 `/var/jb` 链接或 `/bin/bash` 为 20 分，因为可能残留；随机 jbroot 名称为 15 分，有 dpkg/basebin 佐证才 40 分；注入库和函数来源为 35 分；root UID/GID 或 wheel/daemon 附加组 40 分，其他非 mobile 身份、身份差异或 admin 附加组 20 分；DYLD 环境变量/可写根 20 分，调试器 15 分。检测器自身的无沙盒/平台权限为预期观测配置，不计分；这些权限不会自动让 UID 变为 root。

文件不存在为「未命中」；权限不足、私有 API 缺失、无有效注册列表或查询错误为「不可判定」，不伪装成通过。评分是透明的启发式规则，不是统计概率，也没有声称能绕过所有隐藏插件。未签名包无法携带生效的 entitlement，安装后的最终权限由安装器决定；若没有无沙盒读取权限，部分文件和私有 API 检测可能不可判定。`Sources/Entitlements.plist` 仅保留为权限配置参考，不用于编译或打包签名。

## 检测范围

- Rootful：Cydia/Sileo、MobileSubstrate、Substitute、libhooker、apt/dpkg、历史 bootstrap 标记。
- Rootless：`/var/jb`、basebin、ElleKit、Sileo、可读取的 Preboot bootstrap 目录。
- RootHide：App Bundle 的 `.jbroot` 链接，Bundle Application/Shared AppGroup 下的随机 `.jbroot-*` 目录，dpkg/basebin 佐证及加载库。
- TrollStore：自身与其他容器的 `_TrollStore`/`_TrollStoreLite` 标记、巨魔 App 目录、LaunchServices 已注册 App。
- URL：公开 `canOpenURL` 加私有 `LSApplicationWorkspace applicationsAvailableForHandlingURLScheme:` 查询处理者。严格匹配巨魔 bundle ID；`com.apple.Magnifier` 属于系统放大镜，单独可打开 `apple-magnifier://` 不算巨魔。URL 关闭时仍通过安装标记及注册信息检测。私有 API 不能读取时保持不可判定。
- UID/EUID/GID/EGID、附加组及名称，dyld 镜像，关键函数 `dladdr` 来源，DYLD 环境变量、P_TRACED、根挂载状态。arm64e 指针用于 `dladdr` 前进行 PAC strip；不手工解引用签名指针。

## 编译与验证

`python scripts/generate_project.py` 可在 Windows 生成 Xcode 工程；macOS 上 `bash scripts/build.sh` 构建双架构未签名 IPA。关闭 Xcode 签名并禁止链接器生成 ad-hoc 签名；不会调用签名工具。CI 运行独立 Foundation 评分与 URL 分类回归，验证 Mach-O 架构、最低系统、两个切片均无 `LC_CODE_SIGNATURE`、App 无 `_CodeSignature` 和描述文件，再构建模拟器、确认 App 启动后存活并截图。模拟器只验证启动/UI，真机各类越狱的准确率需安装实测；未进行真机验证时不能声称检测全部环境成功。

原生 UIKit，自适应深浅主题、动态字体、iPhone/iPad 分享面板。无第三方代码依赖。按用户要求交付未签名 IPA，安装器自行完成安装处理。私有 API 始终检测类和 selector 是否存在，并捕获 Objective-C 异常，但不保证未来系统兼容性。

模拟器观测的是 macOS 宿主环境，因此设备检测项统一标记不可判定、计 0 分，明确显示模拟器限制。CI 验证导出报告结构及该规则，防止宿主 shell/用户组被误判成真机越狱。应用图标使用用户指定图片经内置 ImageGen 仅将深色背景改为白色后的版本，完整图在 `Artwork/AppIcon-white.png`，打包图标尺寸在 asset catalog。

## 依据与限制

- [TrollStore 源码与支持范围](https://github.com/opa334/TrollStore)：Shared/TSUtil.h 安装标记、Shared/TSUtil.m 容器扫描、TrollStore/Resources/Info.plist 的 URL/bundle ID。
- [RootHide 开发文档](https://github.com/RootHide/Developer/blob/main/roothide.md)：随机 jbroot、`.jbroot` 链接和加载路径。
- [Theos LaunchServices 头文件](https://github.com/theos/headers/blob/master/MobileCoreServices/LSApplicationWorkspace.h)：只读 URL 处理者查询。
- [Apple 指针认证说明](https://developer.apple.com/documentation/security/preparing-your-app-to-work-with-pointer-authentication)：arm64e 支持。

RootHide 或其他 hook 可伪造所有本地查询；工具/目录可能是历史残留；变体可能更名。未命中不等于不存在。「完美」只是检测范围内没有证据/错误，不能证明设备绝对安全。采用无沙盒观察器通常更容易取得证据，同时与普通沙盒 App 的可见范围不同。
