# Video Converter (macOS)

> A tiny, native macOS app for fast video transcoding and compression.

![macOS](https://img.shields.io/badge/platform-macOS-lightgrey) ![Swift](https://img.shields.io/badge/language-Swift-orange) ![License](https://img.shields.io/badge/license-MIT-blue)

[中文介绍](README-zh.md)

## Overview

- Video Converter is a native macOS app built with Swift for fast video transcoding, compression, and size optimization on Mac.
- Key scenarios: quickly convert videos to H.264/H.265 (HEVC), adjust bitrate, and compress files for upload or storage savings.

## Features

Minimal, lightweight, and fast: native Swift plus hardware acceleration to transcode large files in minutes.

- **Native Swift macOS app**: designed for desktop performance, responsive UI, and tight system integration.
- **Small binary**: lightweight executable with fast startup.
- **Hardware acceleration**: supports macOS hardware encoding acceleration when available via the system or FFmpeg.
- **Easy to use**: drag-and-drop and CLI-friendly workflow for batch processing.
- **Powered by FFmpeg**: uses a proven transcoding engine for reliable video encoding and packaging.

## Installation & Build

Requirements: macOS, Xcode or Swift toolchain, optional `xcodegen` if you want to generate the project from `project.yml`.

Build quickly with Swift Package Manager:

```bash
swift build
```

Build with Xcode (using xcodegen):

```bash
xcodegen generate
xcodebuild -project VideoConverter.xcodeproj -scheme VideoConverter -configuration Release build
```

Run the packaged app from the Releases section:

1. Download `VideoConverter.app.zip` from the release.
2. Unzip and open `VideoConverter.app`.

## FFmpeg

- The app uses `FFmpeg` internally for actual transcoding. Make sure `ffmpeg` is available on your system or set the FFmpeg path in the app settings.

## Contributing

- Issues, PRs, and suggestions are welcome. Please fork the repository and open a pull request.

## License

- MIT

---

For more information, check the repository Issues and Releases pages to download the latest packaged version.

---

mac video converter, macOS video transcoder, video compressor mac, FFmpeg mac GUI, swift video converter, HEVC transcode, H.264 convert mac, hardware accelerated transcoding
