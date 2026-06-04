import AppKit
import SwiftUI

struct SelectView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedFolder == nil && !appState.isScanning {
                emptyStateView
            } else if appState.isScanning {
                scanningOverlay
            } else {
                fileListView
            }
        }
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("选择包含视频文件的文件夹")
                    .font(.title3)
                    .foregroundColor(.primary)
            }

            Button(action: { openFolderPicker() }) {
                Label("选择文件夹", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 扫描中加载界面
    private var scanningOverlay: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                Text("正在扫描文件夹...")
                    .font(.headline)

                Text(appState.selectedFolder?.path ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)

                if appState.videoFiles.count > 0 {
                    Text("已找到 \(appState.videoFiles.count) 个视频文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 文件列表视图
    private var fileListView: some View {
        VStack(spacing: 16) {
            // 文件夹信息头部
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                Text(appState.selectedFolder?.lastPathComponent ?? "")
                    .font(.headline)
                Spacer()
                Text("\(appState.videoFiles.count) 个待转码")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("更换文件夹") {
                    appState.selectedFolder = nil
                    appState.videoFiles = []
                }
                .buttonStyle(.link)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))

            // 文件列表（仅显示未完成的）
            List {
                ForEach(appState.videoFiles) { file in
                    HStack(spacing: 12) {
                        Image(systemName: "film")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(file.url.lastPathComponent)
                            .lineLimit(1)
                            .help(file.url.path)
                        Spacer()
                        Text(formatFileSize(bytes: file.size))
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(formatDuration(seconds: file.duration))
                            .foregroundColor(.secondary)
                            .font(.caption.monospaced())
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // 开始按钮
            HStack {
                Spacer()
                Button(action: {
                    appState.currentPage = .settings
                }) {
                    Label("编码设置", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.videoFiles.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "选择包含视频文件的文件夹"
        panel.prompt = "选择"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                appState.selectedFolder = url
                scanFolder(url)
            }
        }
    }

    private func scanFolder(_ folderURL: URL) {
        appState.isScanning = true
        appState.videoFiles = []

        // 先尝试加载日志，获取 targetFolder 来跳过输出目录
        let existingLog = LogManager.shared.loadLog(for: folderURL)
        let skipDirName: String?
        if let log = existingLog {
            skipDirName = URL(fileURLWithPath: log.targetFolder).lastPathComponent
        } else {
            skipDirName = appState.settings.outputSubdir ? "new" : nil
        }

        Task.detached {
            let foundFiles = await ScanHelper.scanFolder(folderURL, skipDirName: skipDirName)
            await MainActor.run {
                appState.isScanning = false

                if let log = existingLog {
                    appState.currentLog = log
                    appState.videoFiles = filterCompletedFiles(foundFiles, log: log)
                } else {
                    var newLog = ProjectLog(sourceFolder: folderURL)
                    newLog.updateSettings(from: appState.settings)
                    appState.currentLog = newLog
                    appState.videoFiles = foundFiles
                }
            }
        }
    }

    /// 根据日志过滤：排除已完成（输出文件存在）的文件，只保留待转码的
    private func filterCompletedFiles(_ files: [VideoFile], log: ProjectLog) -> [VideoFile] {
        // 恢复编码设置
        log.applySettings(to: &appState.settings)

        // 获取日志中已完成且输出文件确实存在的源文件路径集合
        let completedPaths = log.completedSourcePaths()

        // 保留不在集合中的文件（待转码）
        return files.filter { file in
            !completedPaths.contains(file.url.path)
        }
    }

    private func formatFileSize(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDuration(seconds: Double) -> String {
        guard seconds > 0 else { return "--:--" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

enum ScanHelper {
    /// 扫描文件夹中的视频文件
    /// - Parameters:
    ///   - folderURL: 源文件夹路径
    ///   - skipDirName: 需跳过的子目录名（如 "new"），为 nil 则不跳过
    ///   - skipIfFaststart: 为 true 时跳过已 faststart 优化的文件
    static func scanFolder(
        _ folderURL: URL, skipDirName: String? = nil
    ) async -> [VideoFile] {
        let fileManager = FileManager.default
        let supportedExtensions = [
            "mp4", "mov", "m4v", "mkv", "rmvb", "avi",
            "wmv", "flv", "webm", "mts", "m2ts", "ts",
            "3gp", "3g2", "ogv", "ogg", "asf", "vob",
        ]
        var foundFiles: [VideoFile] = []

        guard
            let enumerator = fileManager.enumerator(
                at: folderURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles])
        else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            // 跳过输出目录中的文件
            if let skipDir = skipDirName {
                let relativePath = fileURL.path.replacingOccurrences(of: folderURL.path, with: "")
                let components = relativePath.split(separator: "/")
                if components.contains(Substring(skipDir)) {
                    enumerator.skipDescendants()
                    continue
                }
            }

            let ext = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .fileSizeKey, .isRegularFileKey,
                ])
                guard resourceValues.isRegularFile == true else { continue }
                let size = Int64(resourceValues.fileSize ?? 0)
                let duration = SyncFFmpeg.getVideoDuration(url: fileURL)
                let videoFile = VideoFile(
                    id: UUID(),
                    url: fileURL,
                    size: size,
                    duration: duration
                )
                foundFiles.append(videoFile)
            } catch {
                continue
            }
        }

        return foundFiles
    }
}

enum SyncFFmpeg {
    static func getVideoDuration(url: URL) -> Double {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
        process.arguments = [
            "-v", "error", "-show_entries", "format=duration", "-of",
            "default=noprint_wrappers=1:nokey=1", url.path,
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
                let duration = Double(output)
            {
                return duration
            }
        } catch {
        }
        return 0
    }
}
