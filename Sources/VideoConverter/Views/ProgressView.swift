import AppKit
import SwiftUI

struct ProgressView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("转码进度".localized)
                    .font(.title2.bold())
                Spacer()

                // 屏幕常亮勾选框
                if appState.isEncoding || appState.isPaused {
                    Toggle(isOn: $appState.keepScreenOn) {
                        Text("屏幕常亮".localized)
                            .font(.subheadline)
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: appState.keepScreenOn) { newValue in
                        if newValue {
                            appState.preventSleep()
                        } else {
                            appState.allowSleep()
                        }
                    }
                }

                if appState.isPaused {
                    PausedBadge()
                }
            }
            .padding()

            Divider()

            if appState.videoFiles.isEmpty
                || (!appState.isEncoding && !appState.isPaused && appState.completedFiles.isEmpty)
            {
                waitingStateView
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        overallProgressCard

                        if appState.isEncoding {
                            currentFileCard
                        }

                        if let error = appState.currentEncodingError {
                            errorCard(error)
                        }

                        if !appState.completedFiles.isEmpty {
                            completedFilesList
                        }
                    }
                    .padding()
                }
            }

            Divider()

            bottomToolbar
                .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Subviews

    private var waitingStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "gearshape.2")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("准备开始转码".localized)
                .font(.title3)
                .foregroundColor(.secondary)
            Text("点击\"开始转码\"启动处理".localized)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var overallProgressCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("总体进度".localized, systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(overallProgressPercent)%")
                    .font(.title3.monospaced().bold())
                    .foregroundColor(.accentColor)
            }

            SwiftUI.ProgressView(value: overallProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack {
                Text(
                    "已完成 %d / %d 个".localized(
                        appState.progress.completedFiles, appState.progress.totalFiles)
                )
                .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                Label(
                    "已进行 %@".localized(formatTime(appState.progress.totalElapsedSoFar)),
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                Label("预计剩余 %@".localized(formatTime(estimatedRemaining)), systemImage: "hourglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private var currentFileCard: some View {
        VStack(spacing: 10) {
            HStack {
                Label("当前文件".localized, systemImage: "doc.on.doc")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(appState.progress.currentFileIndex + 1)/\(appState.progress.totalFiles)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(currentFileName)
                    .font(.headline)
                    .lineLimit(1)
                    .help(currentFileName)
                Spacer()
            }

            SwiftUI.ProgressView(value: appState.progress.currentFileProgress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatTime(appState.progress.currentFileElapsed))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                if appState.progress.currentFileProgress > 0 {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("剩余 %@".localized(formatTime(estimatedFileRemaining)))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private func errorCard(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("转码出错".localized, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(10)
    }

    private var completedFilesList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    "已完成 (%d)".localized(appState.completedFiles.count),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundColor(.green)
                Spacer()
                Text(compressionSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            ForEach(appState.completedFiles) { file in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.originalName)
                            .font(.caption)
                            .lineLimit(1)
                        Text("\(formatSize(file.originalSize)) → \(formatSize(file.outputSize))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(Int(file.compressionRatio * 100))%")
                        .font(.caption.monospaced().bold())
                        .foregroundColor(file.compressionRatio < 1 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: {
                if appState.isEncoding {
                    appState.isPaused = true
                    FFmpegRunner.shared.pause()
                } else if appState.isPaused {
                    appState.isPaused = false
                    FFmpegRunner.shared.resume()
                } else {
                    appState.currentPage = .settings
                }
            }) {
                Label("上一步".localized, systemImage: "arrow.left")
            }
            .buttonStyle(.borderless)

            Spacer()

            if appState.isEncoding || appState.isPaused {
                Button(action: {
                    if appState.isPaused {
                        appState.isPaused = false
                        FFmpegRunner.shared.resume()
                    } else {
                        appState.isPaused = true
                        FFmpegRunner.shared.pause()
                    }
                }) {
                    Label(
                        appState.isPaused ? "继续转码".localized : "暂停转码".localized,
                        systemImage: appState.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    appState.isPaused = true
                    FFmpegRunner.shared.pause()
                    saveProgressAndStop()
                }) {
                    Label("停止".localized, systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            if !appState.isEncoding && !appState.isPaused && !appState.completedFiles.isEmpty {
                Button(action: {
                    appState.reset()
                    appState.currentPage = .select
                }) {
                    Label("完成".localized, systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 计算属性

    // MARK: - 计算属性
    private var overallProgress: Double {
        guard appState.progress.totalFiles > 0 else { return 0 }
        return Double(appState.progress.completedFiles) / Double(appState.progress.totalFiles)
    }

    private var overallProgressPercent: Int {
        Int(overallProgress * 100)
    }

    // 新算法：预计剩余时间 = (剩余文件数 - 1) × 平均单个文件时间 + 当前文件预计完成时间
    private var estimatedRemaining: TimeInterval {
        guard appState.progress.completedFiles > 0 else { return 0 }
        let avgTime = appState.progress.totalElapsedSoFar / Double(appState.progress.completedFiles)
        let remainingFiles = appState.progress.totalFiles - appState.progress.completedFiles
        let currentFileEstimate = estimatedFileRemaining
        return Double(remainingFiles - 1) * avgTime + currentFileEstimate
    }

    private var estimatedFileRemaining: TimeInterval {
        guard appState.progress.currentFileProgress > 0 else { return 0 }
        let elapsed = appState.progress.currentFileElapsed
        let progress = appState.progress.currentFileProgress
        return (elapsed / progress) * (1 - progress)
    }

    private var currentFileName: String {
        let index = appState.progress.currentFileIndex
        guard index >= 0 && index < appState.videoFiles.count else { return "" }
        return appState.videoFiles[index].url.lastPathComponent
    }

    private var compressionSummary: String {
        guard !appState.completedFiles.isEmpty else { return "" }
        let totalOriginal = appState.completedFiles.reduce(0) { $0 + $1.originalSize }
        let totalOutput = appState.completedFiles.reduce(0) { $0 + $1.outputSize }
        guard totalOriginal > 0 else { return "" }
        let ratio = Double(totalOutput) / Double(totalOriginal)
        return "平均压缩至 %d%%".localized(Int(ratio * 100))
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        guard interval > 0 && !interval.isNaN && !interval.isInfinite else { return "--:--" }
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func saveProgressAndStop() {
        // 删除当前残缺的输出文件
        if let folder = appState.selectedFolder,
            appState.progress.currentFileIndex < appState.videoFiles.count
        {
            let videoFile = appState.videoFiles[appState.progress.currentFileIndex]
            let outputURL = AppState.outputURL(
                for: videoFile.url,
                outputSubdir: appState.settings.outputSubdir,
                baseFolder: folder
            )
            if outputURL.standardizedFileURL.path
                != videoFile.url.standardizedFileURL.path
            {
                try? FileManager.default.removeItem(at: outputURL)
            }
        }

        // 弹出确认退出对话框
        let alert = NSAlert()
        alert.messageText = "确认退出".localized
        alert.informativeText = "当前正在转码的文件将被中断，已完成部分会被丢弃。\n已完成的文件不受影响。\n确定要退出程序吗？".localized
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出".localized)
        alert.addButton(withTitle: "取消".localized)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

}

// MARK: - 暂停状态徽章
struct PausedBadge: View {
    var body: some View {
        Label("已暂停".localized, systemImage: "pause.circle.fill")
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(6)
    }
}
