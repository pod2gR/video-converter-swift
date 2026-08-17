import Foundation
import os

final class FFmpegRunner: @unchecked Sendable {
    static let shared = FFmpegRunner()

    private var currentProcess: Process?
    private var isCancelledValue: Bool = false
    private var isPausedValue: Bool = false
    private let isCancelledLock = NSLock()
    private let isPausedLock = OSAllocatedUnfairLock()

    // MARK: - 音频编码兼容性

    /// MP4 容器兼容的音频编码（可直接 -c:a copy）
    private static let mp4CompatibleAudioCodecs: Set<String> = [
        "aac", "mp3", "ac3", "eac3", "alac", "opus",
    ]

    /// 使用 ffprobe 检测源文件的音频编码格式
    nonisolated func detectAudioCodec(url: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffprobe")
            process.arguments = [
                "-v", "error",
                "-select_streams", "a:0",
                "-show_entries", "stream=codec_name",
                "-of", "default=noprint_wrappers=1:nokey=1",
                url.path,
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let codec = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: (codec?.isEmpty == false) ? codec : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// 判断音频编码是否可直接封装进 MP4
    nonisolated func isMP4CompatibleAudio(_ codec: String?) -> Bool {
        guard let codec = codec else { return false }
        return Self.mp4CompatibleAudioCodecs.contains(codec.lowercased())
    }

    var isCancelled: Bool {
        isCancelledLock.lock()
        defer { isCancelledLock.unlock() }
        return isCancelledValue
    }

    var isPaused: Bool {
        isPausedLock.lock()
        defer { isPausedLock.unlock() }
        return isPausedValue
    }

    nonisolated func checkFFmpegInstalled() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        process.arguments = ["-version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    nonisolated func getVideoDuration(url: URL) async -> Double? {
        return await withCheckedContinuation { continuation in
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
                    continuation.resume(returning: duration)
                } else {
                    continuation.resume(returning: nil)
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    func encodeVideo(
        inputURL: URL,
        outputURL: URL,
        settings: EncodingSettings,
        progressHandler: @escaping @Sendable (Double) -> Void,
        completion: @escaping @Sendable (Bool, String?) -> Void
    ) {
        isCancelledValue = false

        // 终止之前的进程（如果还在运行）
        currentProcess?.terminate()

        // 防止输入输出路径相同导致 ffmpeg 报错，甚至后续清理误删源文件
        if inputURL.standardizedFileURL.path == outputURL.standardizedFileURL.path {
            completion(false, "输入与输出路径相同".localized)
            return
        }

        Task {
            // 提前检测音频编码和原视频时长
            let audioCodec = await detectAudioCodec(url: inputURL)
            let totalDuration = await getVideoDuration(url: inputURL) ?? 0

            // 根据文件大小和时长计算原始码率，再按压缩档位换算目标码率
            let originalBitrate: Double
            if totalDuration > 0 {
                let fileSize =
                    (try? FileManager.default.attributesOfItem(atPath: inputURL.path)[.size]
                        as? Int64) ?? 0
                originalBitrate = Double(fileSize) * 8.0 / totalDuration  // bits/sec
            } else {
                originalBitrate = 5_000_000  // 兜底：5 Mbps
            }
            let targetBitrate = originalBitrate * settings.crf.bitrateRatio

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")

            let args = buildFFmpegArguments(
                input: inputURL, output: outputURL, settings: settings,
                audioCodec: audioCodec, targetBitrate: targetBitrate
            )
            process.arguments = args

            // 分开收集 stderr（进度+报错都在 stderr）
            let stderrPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = stderrPipe

            // 累积全部 stderr 输出，用于报错时记录日志
            var stderrBuffer = Data()

            do {
                try process.run()
                currentProcess = process

                while process.isRunning && !isCancelled {
                    // 检查暂停状态
                    let paused = isPaused
                    if paused {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        continue
                    }

                    let data = stderrPipe.fileHandleForReading.availableData
                    if !data.isEmpty {
                        stderrBuffer.append(data)
                        if let output = String(data: data, encoding: .utf8) {
                            if let timeMatch = parseTime(from: output), totalDuration > 0 {
                                let progress = timeMatch / totalDuration
                                progressHandler(min(progress, 1.0))
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                if isCancelled {
                    process.terminate()
                    completion(false, "Cancelled")
                } else {
                    // 读取残留的 stderr 数据
                    process.waitUntilExit()
                    let remaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    if !remaining.isEmpty { stderrBuffer.append(remaining) }

                    if process.terminationStatus == 0 {
                        completion(true, nil)
                    } else {
                        // 记录错误日志到文件
                        let stderrText =
                            String(data: stderrBuffer, encoding: .utf8) ?? "(binary output)"
                        saveErrorLog(
                            stderr: stderrText,
                            sourceURL: inputURL,
                            outputURL: outputURL,
                            exitCode: process.terminationStatus
                        )
                        let shortError =
                            extractFFmpegError(from: stderrText)
                            ?? "FFmpeg 异常退出 (code: %d)".localized(process.terminationStatus)
                        completion(false, shortError)
                    }
                }
            } catch {
                // 进程启动失败（如 ffmpeg 未安装）
                let stderrText = String(data: stderrBuffer, encoding: .utf8) ?? ""
                if !stderrText.isEmpty {
                    saveErrorLog(
                        stderr: stderrText, sourceURL: inputURL,
                        outputURL: outputURL, exitCode: -1
                    )
                }
                completion(false, error.localizedDescription)
            }
            // 进程结束后清空引用
            if currentProcess === process {
                currentProcess = nil
            }
        }
    }

    func cancel() {
        isCancelledValue = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    func cancelAll() {
        isCancelledValue = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    func pause() {
        isPausedLock.lock()
        defer { isPausedLock.unlock() }

        guard !isPausedValue else { return }
        isPausedValue = true

        if let process = currentProcess, process.isRunning {
            process.suspend()
        }
    }

    func resume() {
        isPausedLock.lock()
        defer { isPausedLock.unlock() }

        guard isPausedValue else { return }
        isPausedValue = false

        if let process = currentProcess, process.isRunning {
            process.resume()
        }
    }

    private nonisolated func buildFFmpegArguments(
        input: URL, output: URL, settings: EncodingSettings,
        audioCodec: String?, targetBitrate: Double
    ) -> [String] {
        var args = ["-i", input.path]

        // 只映射视频、音频、字幕流（跳过 data 等不兼容流）
        args += ["-map", "0:v"]
        if audioCodec != nil {
            args += ["-map", "0:a"]
        }
        args += ["-map", "0:s?"]
        // 字幕转为 MP4 兼容格式
        args += ["-c:s", "mov_text"]
        // 保留原始元数据（tag、封面等）
        args += ["-map_metadata", "0"]
        args += ["-c:v", "hevc_videotoolbox"]
        args += ["-allow_sw", "0"]  // 仅硬件编码
        // 根据原码率计算的目标码率（H.265 约需 H.264 一半码率保持同画质）
        let bitrateKbps = Int(targetBitrate / 1000)
        args += ["-b:v", "\(bitrateKbps)k"]
        args += settings.crf.encoderFlags
        args += ["-tag:v", "hvc1"]  // 更好的播放器兼容性

        // 音频：兼容编码直接复制，不兼容则 AAC 转码
        if let codec = audioCodec {
            if isMP4CompatibleAudio(codec) {
                args += ["-c:a", "copy"]
            } else {
                args += ["-c:a", "aac", "-b:a", "128k"]
            }
        }

        if let scale = settings.resolution.scaleValue {
            args += ["-vf", "scale=\(scale)"]
        }

        if let fps = settings.frameRate.fpsValue {
            args += ["-r", fps]
        }

        // 在线播放优化（moov atom 前置）
        args += ["-movflags", "+faststart"]
        args += ["-y", output.path]

        return args
    }

    private nonisolated func parseTime(from output: String) -> Double? {
        let pattern = "time=(\\d{2}):(\\d{2}):(\\d{2})\\.(\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: output, range: NSRange(output.startIndex..., in: output))
        else {
            return nil
        }

        let hourRange = Range(match.range(at: 1), in: output)!
        let minRange = Range(match.range(at: 2), in: output)!
        let secRange = Range(match.range(at: 3), in: output)!

        let hours = Double(output[hourRange]) ?? 0
        let minutes = Double(output[minRange]) ?? 0
        let seconds = Double(output[secRange]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }

    // MARK: - 错误日志与信息提取

    /// 从 ffmpeg stderr 中提取最后一条有意义的错误信息
    private nonisolated func extractFFmpegError(from stderr: String) -> String? {
        let lines = stderr.components(separatedBy: "\n")
        // 优先找含有关键错误词的行
        for line in lines.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let lower = trimmed.lowercased()
            if lower.contains("error") || lower.contains("invalid")
                || lower.contains("failed") || lower.contains("unable")
                || lower.contains("not supported")
            {
                return trimmed
            }
        }
        // 兜底：返回最后一行非空内容
        return lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })?
            .trimmingCharacters(in: .whitespaces)
    }

    /// 将 ffmpeg 错误输出追加写入源文件夹下的错误日志
    private nonisolated func saveErrorLog(
        stderr: String,
        sourceURL: URL,
        outputURL: URL,
        exitCode: Int32
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())

        let entry = """
            === \(timestamp) ===
            源文件: \(sourceURL.path)
            输出目标: \(outputURL.path)
            退出码: \(exitCode)
            FFmpeg stderr:
            \(stderr)

            """

        // 写入源文件夹下的错误日志
        let logDir = sourceURL.deletingLastPathComponent()
        let errorLogURL = logDir.appendingPathComponent("video_converter_errors.log")

        if let handle = try? FileHandle(forWritingTo: errorLogURL) {
            handle.seekToEndOfFile()
            if let data = entry.data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        } else {
            try? entry.data(using: .utf8)?.write(to: errorLogURL, options: .atomic)
        }
    }
}
