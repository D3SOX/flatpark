---
title: 收录政策
description: FlatPark 接受哪些应用、审核标准以及下架流程。
group: Project
order: 2
---

FlatPark 收录提供公开、稳定发布 URL 且可打包为 [extra-data](/zh-Hans/trust/) 的应用。以下规则适用于应用的收录和持续上架。

## 我们收录的应用

任何在稳定公开 URL 上提供官方预构建下载产物的应用都可以收录，包括安装程序、`.deb`、`.rpm` 或 tarball。FlatPark 会在构建时获取产物，按 checksum 固定产物并对结果签名。FlatPark 从不自行从源码构建应用，也从不重新托管 binary。（不接受 AppImage。）软件包可以从固定的源码构建 runtime 缺少的支持库，但应用本身始终是厂商自己的 binary。

Toolkit 和许可证不会成为收录门槛。**欢迎 Electron 和 Tauri 应用**——registry 中已经提供这两类应用——也**欢迎闭源应用**。只要 upstream 发布 `.deb`、`.rpm`、tarball、zip 或官方安装程序，就可以在这里打包。

## 要求

- 官方构建必须有**稳定、公开的发布 URL**（不得要求登录）。
- 必须有 **AppStream metainfo** 文件（`<id>.metainfo.xml`），其中包含 id、名称、摘要、许可证以及至少一个描述段落。
- **id 必须符合 reverse-DNS 格式**，并与 registry 目录名称一致。
- 使用**当前 runtime 主版本**，与应用目录中的其他应用保持一致。不接受为了规避构建故障而固定旧主版本——一个未升级的应用就会迫使每位用户在磁盘上保留第二套 runtime。
- 使用仍能正常工作的**最严格 `finish-args`**。可选功能**默认不授予权限**：不要添加对应权限，而是在应用描述中记录用于启用权限的 `flatpak override` 命令，让每位用户自行决定。应用正常运行确实需要的权限应保留在 `finish-args` 中，并在 PR 里说明理由。
- **提交 PR 前已在本地测试**——提交者已经构建应用、使用 `flatpak install` 安装、启动应用，并确认其核心功能正常。
- 明确说明应用的**许可证**。

## Vibe-coded 应用

欢迎使用 AI 辅助开发（“vibe coding”）的应用。它们与其他应用采用相同标准评判：考察开发历史、upstream 活跃度和实际表现出的质量，而不是编写方式。

## 审核

每项提交都会按照公开的[审核 runbook](https://github.com/flatpark/flatpark/blob/main/docs/pr-review.md)进行审核（有 AI 辅助）。信任问题的关键在于**你运行的内容来自哪里**，而不是许可证：

- FlatPark 要么根据公开源码验证从源码构建的软件包，要么重新打包**未经修改的 upstream 官方预构建产物**——你运行的内容就是厂商自己的产物。
- 官方预构建产物必须来自真正的 upstream/厂商发布渠道。托管在提交者个人账户或 mirror 上的 binary，以及打包过程中重新构建或打过 patch 的 binary，都会被拒绝。
- 每项下载都按 `sha256`（及大小）固定，所有 git 源也固定到不可变的 commit，因此构建过程无法悄悄替换内容。
- 会逃逸 sandbox 的权限（host 文件系统、Flatpak 控制 bus）会被拒绝；范围宽泛的授权必须说明理由。
- **允许 non-FOSS 应用**——是否开源不是审核标准。我们会根据用途而非许可证拒绝盗版、恶意软件、冒充商标或任何无法合法分发的内容。

我们并不声称每个开源预构建产物都经过了逐字节的源码验证——只保证它是 upstream 官方构建、已固定且未经修改。

## 下架

出现以下情况时，可以从 FlatPark 移除应用：

- 官方下载 URL 消失或停止维护；
- upstream 已被放弃，或发现某个发布版本包含恶意内容；
- 应用请求了无法合理解释的危险权限；或
- 厂商要求我们将其移除。

流程是公开的：先新建 issue 说明原因，再由维护者审核；应用被移除后，会从 registry 中删除其目录，并从 repo 中移除对应 ref。已安装的副本仍可继续使用，直至用户将其卸载。
