import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text("编码设置".localized)
                    .font(.title2.bold())
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // 分辨率选择
                    settingsSection(
                        title: "分辨率".localized, systemImage: "rectangle.arrowtriangle.2.outward"
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            RadioOption(
                                title: ResolutionOption.original.title,
                                isSelected: appState.settings.resolution == .original,
                                action: { appState.settings.resolution = .original }
                            )
                            RadioOption(
                                title: ResolutionOption.p1080.title,
                                isSelected: appState.settings.resolution == .p1080,
                                action: { appState.settings.resolution = .p1080 }
                            )
                            RadioOption(
                                title: ResolutionOption.p720.title,
                                isSelected: appState.settings.resolution == .p720,
                                action: { appState.settings.resolution = .p720 }
                            )
                            RadioOption(
                                title: ResolutionOption.p480.title,
                                isSelected: appState.settings.resolution == .p480,
                                action: { appState.settings.resolution = .p480 }
                            )
                        }
                    }

                    // 帧率选择
                    settingsSection(title: "帧率".localized, systemImage: "speedometer") {
                        VStack(alignment: .leading, spacing: 4) {
                            RadioOption(
                                title: FrameRateOption.original.title,
                                isSelected: appState.settings.frameRate == .original,
                                action: { appState.settings.frameRate = .original }
                            )
                            RadioOption(
                                title: FrameRateOption.fps60.title,
                                isSelected: appState.settings.frameRate == .fps60,
                                action: { appState.settings.frameRate = .fps60 }
                            )
                            RadioOption(
                                title: FrameRateOption.fps30.title,
                                isSelected: appState.settings.frameRate == .fps30,
                                action: { appState.settings.frameRate = .fps30 }
                            )
                            RadioOption(
                                title: FrameRateOption.fps29_97.title,
                                isSelected: appState.settings.frameRate == .fps29_97,
                                action: { appState.settings.frameRate = .fps29_97 }
                            )
                            RadioOption(
                                title: FrameRateOption.fps24.title,
                                isSelected: appState.settings.frameRate == .fps24,
                                action: { appState.settings.frameRate = .fps24 }
                            )
                        }
                    }

                    // 压缩比例（H.264 → H.265，根据原码率自动换算）
                    settingsSection(title: "压缩比例".localized, systemImage: "arrow.up.arrow.down") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                "自动探测原视频码率，H.265 同画质约需 H.264 一半码率。所有模式均启用 -prio_speed 0 + -spatial_aq 1 质量旗标。"
                                    .localized
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                RadioOption(
                                    title: CRFOption.qualityCompress.title,
                                    isSelected: appState.settings.crf == .qualityCompress,
                                    action: { appState.settings.crf = .qualityCompress }
                                )
                                RadioOption(
                                    title: CRFOption.standardCompress.title,
                                    isSelected: appState.settings.crf == .standardCompress,
                                    action: { appState.settings.crf = .standardCompress }
                                )
                                RadioOption(
                                    title: CRFOption.strongCompress.title,
                                    isSelected: appState.settings.crf == .strongCompress,
                                    action: { appState.settings.crf = .strongCompress }
                                )
                            }
                        }
                    }

                    // 输出设置
                    settingsSection(title: "输出".localized, systemImage: "folder") {
                        Toggle("输出到子目录 \"new\"".localized, isOn: $appState.settings.outputSubdir)
                            .toggleStyle(.switch)
                    }
                }
                .padding()
            }

            Divider()

            // 底部按钮
            HStack {
                Button(action: {
                    appState.currentPage = .select
                }) {
                    Label("上一步".localized, systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button(action: {
                    appState.currentPage = .progress
                    startEncoding()
                }) {
                    Label("开始转码".localized, systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private func startEncoding() {
        appState.isEncoding = true
        appState.currentEncodingError = nil
        appState.preventSleep()
        appState.shouldCancelAll = false

        let settings = appState.settings
        let alreadyCompleted = appState.currentLog?.completedFiles.count ?? 0
        // totalFiles = 待转码文件数 + 已完成文件数（全部文件总数）
        let totalFiles = appState.videoFiles.count + alreadyCompleted

        // 将编码设置保存到日志
        if var log = appState.currentLog, let folder = appState.selectedFolder {
            log.updateSettings(from: settings)
            LogManager.shared.saveLog(log, to: folder)
            appState.currentLog = log
        }

        let outputDir = appState.selectedFolder?.appendingPathComponent("new")

        if settings.outputSubdir, let outputDir = outputDir {
            try? FileManager.default.createDirectory(
                at: outputDir, withIntermediateDirectories: true)
        }

        // 初始化进度
        appState.progress = EncodingProgress(totalFiles: totalFiles)
        appState.progress.completedFiles = alreadyCompleted

        Task {
            for (index, videoFile) in appState.videoFiles.enumerated() {
                if appState.shouldCancelAll {
                    await MainActor.run {
                        appState.isEncoding = false
                        appState.allowSleep()
                    }
                    break
                }

                await MainActor.run {
                    appState.progress.currentFileIndex = index
                    appState.progress.currentFileProgress = 0
                    appState.progress.currentFileElapsed = 0
                }

                let outputFileName =
                    videoFile.url.deletingPathExtension().lastPathComponent + ".mp4"
                let outputURL: URL
                if settings.outputSubdir, let outputDir = outputDir {
                    outputURL = outputDir.appendingPathComponent(outputFileName)
                } else {
                    outputURL = videoFile.url.deletingPathExtension().appendingPathExtension("mp4")
                }

                let startTime = Date()

                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    FFmpegRunner.shared.encodeVideo(
                        inputURL: videoFile.url,
                        outputURL: outputURL,
                        settings: settings,
                        progressHandler: { progress in
                            Task { @MainActor in
                                appState.progress.currentFileProgress = progress
                                appState.progress.currentFileElapsed = Date().timeIntervalSince(
                                    startTime)
                            }
                        },
                        completion: { success, error in
                            Task { @MainActor in
                                let fileElapsed = Date().timeIntervalSince(startTime)
                                if success {
                                    let outputSize =
                                        (try? FileManager.default.attributesOfItem(
                                            atPath: outputURL.path)[.size] as? Int64) ?? 0
                                    let completed = CompletedFile(
                                        id: UUID(),
                                        originalName: videoFile.url.lastPathComponent,
                                        originalSize: videoFile.size,
                                        outputSize: outputSize,
                                        outputURL: outputURL
                                    )
                                    appState.completedFiles.append(completed)
                                    appState.progress.completedFiles += 1
                                    appState.progress.currentFileProgress = 1.0
                                    appState.progress.totalElapsedSoFar += fileElapsed

                                    // 写入日志：标记此文件已完成
                                    if var log = appState.currentLog,
                                        let folder = appState.selectedFolder
                                    {
                                        log.markCompleted(
                                            sourcePath: videoFile.url.path,
                                            outputPath: outputURL.path,
                                            sourceSize: videoFile.size,
                                            outputSize: outputSize
                                        )
                                        LogManager.shared.saveLog(log, to: folder)
                                        appState.currentLog = log
                                    }
                                } else {
                                    // 编码失败 → 删除残缺输出文件
                                    try? FileManager.default.removeItem(at: outputURL)
                                    appState.currentEncodingError = error ?? "Unknown error"
                                }
                                continuation.resume()
                            }
                        }
                    )
                }
            }

            await MainActor.run {
                appState.isEncoding = false
                appState.allowSleep()
            }
        }
    }
}

// MARK: - 单选框组件
struct RadioOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .imageScale(.small)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
