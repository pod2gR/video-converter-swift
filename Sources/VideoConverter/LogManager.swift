import Foundation

// MARK: - 已完成文件条目
struct CompletedFileEntry: Codable {
    let sourcePath: String
    let outputPath: String
    let sourceSize: Int64
    let outputSize: Int64
    let completedAt: Date
}

// MARK: - 项目日志（只记录已完成文件 + 编码设置）
struct ProjectLog: Codable {
    var sourceFolder: String
    var targetFolder: String
    var resolution: String = "保持原分辨率"
    var frameRate: String = "29.97"
    var crf: String = "标准压缩（原码率 50%）"
    var outputSubdir: Bool = true
    var completedFiles: [CompletedFileEntry] = []
    var createdAt: Date
    var updatedAt: Date

    init(sourceFolder: URL) {
        self.sourceFolder = sourceFolder.path
        self.targetFolder = sourceFolder.appendingPathComponent("new").path
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - 查询

    /// 检查某个源文件是否已完成（且输出文件存在）
    func isCompleted(sourcePath: String) -> Bool {
        completedFiles.contains { entry in
            entry.sourcePath == sourcePath
                && FileManager.default.fileExists(atPath: entry.outputPath)
        }
    }

    /// 获取所有源文件路径集合（用于过滤）
    func completedSourcePaths() -> Set<String> {
        Set(
            completedFiles.compactMap { entry in
                FileManager.default.fileExists(atPath: entry.outputPath)
                    ? entry.sourcePath : nil
            })
    }

    // MARK: - 写入

    /// 标记一个文件为已完成
    mutating func markCompleted(
        sourcePath: String, outputPath: String,
        sourceSize: Int64, outputSize: Int64
    ) {
        // 如果已存在同源文件的记录，先移除
        completedFiles.removeAll { $0.sourcePath == sourcePath }
        completedFiles.append(
            CompletedFileEntry(
                sourcePath: sourcePath,
                outputPath: outputPath,
                sourceSize: sourceSize,
                outputSize: outputSize,
                completedAt: Date()
            ))
        updatedAt = Date()
    }

    // MARK: - 设置

    /// 从 EncodingSettings 更新日志中的设置字段
    mutating func updateSettings(from settings: EncodingSettings) {
        resolution = settings.resolution.rawValue
        frameRate = settings.frameRate.rawValue
        crf = settings.crf.rawValue
        outputSubdir = settings.outputSubdir
    }

    /// 将日志中的设置恢复到 EncodingSettings
    func applySettings(to settings: inout EncodingSettings) {
        if let r = ResolutionOption(rawValue: resolution) { settings.resolution = r }
        if let f = FrameRateOption(rawValue: frameRate) { settings.frameRate = f }
        if let c = CRFOption(rawValue: crf) { settings.crf = c }
        settings.outputSubdir = outputSubdir
    }
}

// MARK: - 日志管理器
@MainActor
final class LogManager {
    static let shared = LogManager()
    private let logFileName = "video_converter_log.json"

    private init() {}

    // 获取日志文件路径
    private func logFilePath(in folder: URL) -> URL {
        folder.appendingPathComponent(logFileName)
    }

    // 加载项目日志（如果存在）
    func loadLog(for folder: URL) -> ProjectLog? {
        let path = logFilePath(in: folder)
        guard FileManager.default.fileExists(atPath: path.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ProjectLog.self, from: data)
        } catch {
            print("Failed to load log: \(error)")
            return nil
        }
    }

    // 保存项目日志
    func saveLog(_ log: ProjectLog, to folder: URL) {
        let path = logFilePath(in: folder)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(log)
            try data.write(to: path, options: .atomic)
        } catch {
            print("Failed to save log: \(error)")
        }
    }

    // 删除日志文件
    func deleteLog(for folder: URL) {
        let path = logFilePath(in: folder)
        try? FileManager.default.removeItem(at: path)
    }
}
