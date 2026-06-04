# Video Converter (macOS)

> 轻量级 macOS 视频转码与压缩工具。

![macOS](https://img.shields.io/badge/platform-macOS-lightgrey) ![Swift](https://img.shields.io/badge/language-Swift-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

## 简介

- Video Converter 是一款用 Swift 原生开发的 macOS 应用，针对需要在 Mac 上快速进行视频转码、压缩和体积优化的用户。
- 关键场景：快速将视频转为 H.264/H.265（HEVC）、调整比特率、压缩以便上传或节省存储空间。

## 功能特点

极简、轻量、快速：原生 Swift + 硬件加速，分钟级完成大文件转码。

- **Swift 原生开发**：内建为 macOS 桌面应用，界面响应快速、系统集成友好。
- **体积极小**：不臃肿的二进制体积，启动迅速。
- **硬件加速**：支持 macOS 硬件转码加速（若系统/FFmpeg 支持），速度显著优于纯软件转码。
- **易用**：拖拽或命令行模式，适配批量处理场景。
- **基于 FFmpeg**：利用成熟的转码库实现可靠的视频编码/封装。

## 安装与构建

要求：macOS、Xcode 或 Swift 工具链、可选的 `xcodegen`（若使用 `project.yml` 生成 Xcode 项目）。

快速构建（Swift Package）：

```bash
swift build
```

通过 Xcode 打包（使用 xcodegen 生成工程）：

```bash
xcodegen generate
xcodebuild -project VideoConverter.xcodeproj -scheme VideoConverter -configuration Release build
```

运行已打包应用（本仓库的发行版）：

1. 下载 Release 中的 `VideoConverter.app.zip` 并解压。
2. 双击 `VideoConverter.app` 启动。

## 命令行（FFmpeg）

- 本项目在内部使用 `FFmpeg`（或打包的二进制）执行实际转码；请确保系统上可用 `ffmpeg`，或在设置中指定 FFmpeg 路径。

## 贡献

- 欢迎提 issue、PR 和建议。若要贡献代码，请先 fork 本仓库并发起 PR。

## 许可证

- MIT

---

更多信息请查看仓库的 Issues 和 Releases 页面，下载最新的打包版本开始使用。

---

mac 视频转换器, macOS 视频转码, 视频压缩 mac, FFmpeg mac GUI, Swift 视频转换, HEVC 转码, H.264 转换 mac, 硬件加速转码
