import Foundation

enum AppLanguage {
    case chinese
    case english
}

extension AppLanguage {
    init(localeIdentifier: String) {
        let lowercased = localeIdentifier.lowercased()
        if lowercased.hasPrefix("zh") {
            self = .chinese
        } else {
            self = .english
        }
    }
}

struct Localization {
    static let shared = Localization()

    let language: AppLanguage

    private let englishMap: [String: String] = [
        "选择包含视频文件的文件夹": "Choose a folder containing video files",
        "选择文件夹": "Select Folder",
        "选择": "Choose",
        "正在扫描文件夹...": "Scanning folder...",
        "已找到 %d 个视频文件": "Found %d video files",
        "个待转码": " files pending transcoding",
        "更换文件夹": "Change Folder",
        "编码设置": "Encoding Settings",
        "保持原分辨率": "Keep original resolution",
        "高质量压缩（原码率 65%）": "High quality compression (65% of original bitrate)",
        "标准压缩（原码率 50%）": "Standard compression (50% of original bitrate)",
        "强力压缩（原码率 35%）": "Aggressive compression (35% of original bitrate)",
        "分辨率": "Resolution",
        "帧率": "Frame Rate",
        "压缩比例": "Compression",
        "输出": "Output",
        "输出到子目录 \"new\"": "Output to subfolder \"new\"",
        "上一步": "Back",
        "开始转码": "Start Transcoding",
        "转码进度": "Transcoding Progress",
        "屏幕常亮": "Keep Screen On",
        "准备开始转码": "Ready to start transcoding",
        "点击\"开始转码\"启动处理": "Click \"Start Transcoding\" to begin",
        "总体进度": "Overall Progress",
        "已完成 %d / %d 个": "Completed %d / %d",
        "已进行 %@": "Elapsed %@",
        "预计剩余 %@": "Estimated Remaining %@",
        "当前文件": "Current File",
        "剩余 %@": "Remaining %@",
        "转码出错": "Transcoding Error",
        "已完成 (%d)": "Completed (%d)",
        "暂停": "Pause",
        "继续转码": "Resume Transcoding",
        "暂停转码": "Pause Transcoding",
        "停止": "Stop",
        "完成": "Done",
        "确认退出": "Confirm Exit",
        "当前正在转码的文件将被中断，已完成部分会被丢弃。\n已完成的文件不受影响。\n确定要退出程序吗？":
            "The current file being transcoded will be interrupted and any in-progress work will be discarded.\nCompleted files will not be affected.\nDo you want to quit?",
        "平均压缩至 %d%%": "Average compression to %d%%",
        "退出": "Quit",
        "取消": "Cancel",
        "关于 Video Converter": "About Video Converter",
        "打开文件夹...": "Open Folder...",
        "最小化": "Minimize",
        "关闭": "Close",
        "未找到 FFmpeg": "FFmpeg Not Found",
        "Video Converter 需要 FFmpeg 来进行视频转码。请通过 Homebrew 安装：\n\nbrew install ffmpeg\n\n安装完成后请重新启动程序。":
            "Video Converter requires FFmpeg for video transcoding. Please install it with Homebrew:\n\nbrew install ffmpeg\n\nThen restart the app.",
        "文件": "File",
        "编辑": "Edit",
        "窗口": "Window",
        "FFmpeg 异常退出 (code: %d)": "FFmpeg exited with code %d",
        "自动探测原视频码率，H.265 同画质约需 H.264 一半码率。所有模式均启用 -prio_speed 0 + -spatial_aq 1 质量旗标。": "Auto-detect the original bitrate. H.265 needs about half the bitrate of H.264 at the same quality. All modes enable -prio_speed 0 + -spatial_aq 1 for quality.",
        "确定": "OK",
        "保持原帧率": "Keep original frame rate",
    ]

    private init() {
        if let preferred = Locale.preferredLanguages.first {
            self.language = AppLanguage(localeIdentifier: preferred)
        } else {
            self.language = AppLanguage(localeIdentifier: Locale.current.identifier)
        }
    }

    func localized(_ key: String) -> String {
        switch language {
        case .chinese:
            return key
        case .english:
            return englishMap[key] ?? key
        }
    }

    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        let format = localized(key)
        return String(format: format, locale: Locale(identifier: "en_US_POSIX"), arguments: args)
    }
}

extension String {
    var localized: String {
        Localization.shared.localized(self)
    }

    func localized(_ args: CVarArg...) -> String {
        Localization.shared.localizedFormat(self, args)
    }
}
