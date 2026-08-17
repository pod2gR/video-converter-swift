import Foundation
import IOKit.pwr_mgt

struct VideoFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let size: Int64
    let duration: Double

    static func == (lhs: VideoFile, rhs: VideoFile) -> Bool {
        lhs.id == rhs.id
    }
}

enum ResolutionOption: String, CaseIterable {
    case original
    case p1080
    case p720
    case p480

    var title: String {
        switch self {
        case .original: return "保持原分辨率".localized
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
        }
    }

    var scaleValue: String? {
        switch self {
        case .original: return nil
        case .p1080: return "1920:1080"
        case .p720: return "1280:720"
        case .p480: return "854:480"
        }
    }
}

enum FrameRateOption: String, CaseIterable {
    case original
    case fps60
    case fps30
    case fps29_97
    case fps24

    var title: String {
        switch self {
        case .original: return "保持原帧率".localized
        case .fps60: return "60 fps"
        case .fps30: return "30 fps"
        case .fps29_97: return "29.97 fps"
        case .fps24: return "24 fps"
        }
    }

    var fpsValue: String? {
        switch self {
        case .original: return nil
        case .fps60: return "60"
        case .fps30: return "30"
        case .fps29_97: return "29.97"
        case .fps24: return "24"
        }
    }
}

enum CRFOption: String, CaseIterable {
    case qualityCompress
    case standardCompress
    case strongCompress

    var title: String {
        switch self {
        case .qualityCompress: return "高质量压缩（原码率 65%）".localized
        case .standardCompress: return "标准压缩（原码率 50%）".localized
        case .strongCompress: return "强力压缩（原码率 35%）".localized
        }
    }

    /// H.265 目标码率占原码率的比例（H.265 比 H.264 效率高约 40-50%，同画质只需一半码率）
    var bitrateRatio: Double {
        switch self {
        case .qualityCompress: return 0.65
        case .standardCompress: return 0.50
        case .strongCompress: return 0.35
        }
    }

    /// 硬件编码器画质旗标（所有模式统一启用）
    var encoderFlags: [String] {
        [
            "-realtime", "0",  // 离线模式，不求实时
            "-prio_speed", "0",  // 质量优先（非速度优先）
            "-spatial_aq", "1",  // 自适应量化：复杂画面多用码率，平坦区域少用
        ]
    }
}

struct EncodingSettings: Equatable {
    var resolution: ResolutionOption = .original
    var frameRate: FrameRateOption = .original
    var crf: CRFOption = .standardCompress
    var outputSubdir: Bool = true
}

struct EncodingProgress: Equatable {
    var totalFiles: Int = 0
    var completedFiles: Int = 0
    var currentFileIndex: Int = 0
    var currentFileProgress: Double = 0
    var currentFileElapsed: TimeInterval = 0
    var estimatedTotalRemaining: TimeInterval = 0
    var totalElapsedSoFar: TimeInterval = 0  // 所有已完成文件的总耗时
}

struct CompletedFile: Identifiable, Equatable {
    let id: UUID
    let originalName: String
    let originalSize: Int64
    let outputSize: Int64
    let outputURL: URL

    var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(outputSize) / Double(originalSize)
    }
}

class AppState: ObservableObject {
    @Published var selectedFolder: URL?
    @Published var videoFiles: [VideoFile] = []
    @Published var settings: EncodingSettings = EncodingSettings()
    @Published var progress: EncodingProgress = EncodingProgress()
    @Published var completedFiles: [CompletedFile] = []
    @Published var isFFmpegAvailable: Bool = false
    @Published var isScanning: Bool = false
    @Published var isEncoding: Bool = false
    @Published var isPaused: Bool = false
    @Published var shouldCancelAll: Bool = false
    @Published var currentEncodingError: String?

    @Published var currentPage: PageType = .select

    // 日志相关
    @Published var currentLog: ProjectLog?

    // 防锁屏
    private var assertionID: IOPMAssertionID = 0
    private var isPreventingSleep: Bool = false
    @Published var keepScreenOn: Bool = true

    enum PageType: Int, CaseIterable {
        case select = 0
        case settings = 1
        case progress = 2

        var title: String {
            switch self {
            case .select: return "选择文件夹".localized
            case .settings: return "编码设置".localized
            case .progress: return "转码进度".localized
            }
        }
    }

    func reset() {
        videoFiles = []
        settings = EncodingSettings()
        progress = EncodingProgress()
        completedFiles = []
        currentEncodingError = nil
        currentLog = nil
    }

    func resetProject() {
        progress = EncodingProgress()
        completedFiles = []
        currentEncodingError = nil
    }

    func canNavigateToSettings() -> Bool {
        !videoFiles.isEmpty
    }

    func canNavigateToProgress() -> Bool {
        !videoFiles.isEmpty
    }

    /// 计算输出文件路径；确保输出与源文件不冲突（源文件已是 .mp4 且不输出到子目录时加后缀）
    static func outputURL(for input: URL, outputSubdir: Bool, baseFolder: URL) -> URL {
        let outputDir =
            outputSubdir
            ? baseFolder.appendingPathComponent("new")
            : baseFolder
        let baseName = input.deletingPathExtension().lastPathComponent
        var url = outputDir.appendingPathComponent(baseName + ".mp4")
        if url.standardizedFileURL.path == input.standardizedFileURL.path {
            url = outputDir.appendingPathComponent(baseName + "_converted.mp4")
        }
        return url
    }

    // MARK: - 防锁屏

    func preventSleep() {
        guard keepScreenOn, !isPreventingSleep else { return }
        let reason = "Video encoding in progress" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &assertionID)
        if result == kIOReturnSuccess {
            isPreventingSleep = true
        }
    }

    func allowSleep() {
        guard isPreventingSleep else { return }
        IOPMAssertionRelease(assertionID)
        isPreventingSleep = false
    }
}
