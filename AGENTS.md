# AGENTS.md

This file helps AI coding agents understand the `VideoConverter` macOS project and work productively.

## Project overview

- Native macOS app written in Swift.
- Uses Swift Package Manager for source layout and build.
- Uses FFmpeg via `FFmpegRunner.swift` for video transcoding.
- App is a lightweight GUI tool for H.264/H.265 encoding, compression, and file export.

## Key files

- `Sources/VideoConverter/` - main application source.
- `Sources/VideoConverter/Views/` - SwiftUI views and UI layout.
- `Sources/VideoConverter/FFmpegRunner.swift` - FFmpeg command handling and process execution.
- `project.yml` - XcodeGen project definition.
- `Package.swift` - Swift package manifest.
- `README.md` - basic project description and build instructions.

## Build commands

- `swift build`
- `xcodegen generate` then `xcodebuild -project VideoConverter.xcodeproj -scheme VideoConverter -configuration Release build`

## Deployment (打包 .app 与 Release)

本机只有 Command Line Tools，没有完整 Xcode，因此 **不能用 `xcodebuild`**。

- **编译**：`swift build`（debug）或 `swift build -c release`（release，但可能卡住 → 回退用 debug）
- **更新 .app**：编译完成后把二进制拷贝到模板 .app bundle：
  ```bash
  cp .build/debug/VideoConverter dist/VideoConverter.app/Contents/MacOS/VideoConverter
  ```
- **打包为 zip**：
  ```bash
  cd dist && zip -r VideoConverter-vX.Y.Z.zip VideoConverter.app
  ```
- **用 GitHub Release 发布**：
  ```bash
  gh release create vX.Y.Z dist/VideoConverter-vX.Y.Z.zip --title "vX.Y.Z" --notes "..."
  ```

## Git / GitHub 操作注意事项

HTTPS 推送可能卡住或 SSL 超时。本机已安装 `gh` CLI 并已认证（账号 pod2gR），推送前先配置凭据助手：

```bash
git config --local credential.helper '!gh auth git-credential'
GIT_TERMINAL_PROMPT=0 git push origin <branch>
```

设置一次后本地仓库即可正常推送，后续不再需要重复配置。

## Troubleshooting / 已踩过的坑

- **xcodebuild 不可用** → 用 `swift build` 替代，详见上方"Deployment"。
- **`swift build -c release` 卡在编译步骤不动**（如 `[2/5] Write swift-version...`）→ 改用 `swift build`（debug）编译，debug 二进制同样可部署到 .app。
- **HTTPS git push 无响应/超时** → 见上方"Git / GitHub 操作注意事项"。
- **App 主页按钮消失** → 历史上本地化提交把 `Button` 误改为 `Label` 导致不可点击。修改 `SelectView.swift` 的 `emptyStateView` 时确认按钮在外层 VStack 中。
- **编码设置压缩比例选项全部显示相同** → 三个 `RadioOption` 的 title 写了同一个 `appState.settings.crf.title`，应各自用 `CRFOption.xxx.title`。

## Platform and settings

- macOS 13.0 or later
- Swift 6.0
- App uses manual signing and disables sandbox in entitlements

## Important conventions

- Keep the app lightweight and native. Avoid adding heavy external UI frameworks.
- Do not change the FFmpeg integration approach unless the change is explicitly intended.
- If adding new features, update both the app UI and any related state handling in `AppState.swift`.
- Use `Localization.swift` for user-facing strings if localization is needed.

## When editing

- Prefer small, clear changes rather than broad refactors.
- Preserve the current macOS native app architecture and file structure.
- Do not break the paths referenced by `project.yml` and `Package.swift`.

## Notes

- No dedicated test suite exists in this repository.
- The main logic is in the app target; there is no separate library target.
