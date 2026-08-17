import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkFFmpegAvailability()

        let contentView = ContentView()
            .environmentObject(appState)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Video Converter"
        window?.center()
        window?.setFrameAutosaveName("MainWindow")
        window?.contentView = NSHostingView(rootView: contentView)
        window?.makeKeyAndOrderFront(nil)

        window?.minSize = NSSize(width: 700, height: 550)

        setupToolbar()
        setupMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true  // Cmd+W 关闭窗口时退出应用
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 如果正在转码，删除当前残缺输出文件（已完成的不受影响）
        if appState.isEncoding || appState.isPaused {
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
        }
        return .terminateNow
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func checkFFmpegAvailability() {
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: ffmpegPath) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = ["-version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    appState.isFFmpegAvailable = true
                    return
                }
            } catch {
            }
        }

        showFFmpegNotFoundAlert()
        appState.isFFmpegAvailable = false
    }

    private func showFFmpegNotFoundAlert() {
        let alert = NSAlert()
        alert.messageText = "未找到 FFmpeg".localized
        alert.informativeText =
            "Video Converter 需要 FFmpeg 来进行视频转码。请通过 Homebrew 安装：\n\nbrew install ffmpeg\n\n安装完成后请重新启动程序。"
            .localized
        alert.alertStyle = .critical
        alert.addButton(withTitle: "确定".localized)

        if let window = self.window {
            alert.beginSheetModal(for: window) { _ in
                NSApplication.shared.terminate(nil)
            }
        } else {
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }

    private func setupToolbar() {
        guard let window = window else { return }

        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false

        window.toolbar = toolbar
        window.toolbarStyle = .unified
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // 应用菜单
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            withTitle: "关于 Video Converter".localized,
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "退出".localized, action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")

        // 文件菜单
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "文件".localized)
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(
            withTitle: "打开文件夹...".localized, action: #selector(openFolder(_:)), keyEquivalent: "o")

        // 编辑菜单
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "编辑".localized)
        editMenuItem.submenu = editMenu

        editMenu.addItem(
            withTitle: "最小化".localized, action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m")

        // 窗口菜单
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "窗口".localized)
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(
            withTitle: "关闭".localized, action: #selector(NSWindow.close), keyEquivalent: "w")

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func openFolder(_ sender: Any?) {
        // 触发打开文件夹面板
        NotificationCenter.default.post(name: Notification.Name("OpenFolder"), object: nil)
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.navigation]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.navigation]
    }

    func toolbar(
        _ toolbar: NSToolbar, viewForItemIdentifier itemIdentifier: NSToolbarItem.Identifier
    ) -> NSToolbarItem? {
        guard itemIdentifier == .navigation else { return nil }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.target = self
        item.action = #selector(segmentedControlChanged(_:))

        let segmentedControl = NSSegmentedControl(
            labels: AppState.PageType.allCases.map { $0.title }, trackingMode: .selectOne,
            target: self, action: #selector(segmentedControlChanged(_:)))
        segmentedControl.selectedSegment = appState.currentPage.rawValue
        item.view = segmentedControl

        return item
    }

    @objc private func segmentedControlChanged(_ sender: NSSegmentedControl) {
        let selectedIndex = sender.selectedSegment
        if let page = AppState.PageType(rawValue: selectedIndex) {
            if page == .select || appState.canNavigateToSettings() {
                appState.currentPage = page
            }
        }
    }
}

extension NSToolbarItem.Identifier {
    static let navigation = NSToolbarItem.Identifier("NavigationToolbarItem")
}
