// Clammr — clamshell mode without closing the lid: menu bar switch to turn MacBook built-in display off/on. See design.md.
import AppKit
import CoreGraphics
import ServiceManagement

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ config: CGDisplayConfigRef, _ display: CGDirectDisplayID, _ enabled: Bool) -> CGError

let repoURL = URL(string: "https://github.com/slingappa/clammr")!
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

// MARK: - Display helpers

enum Displays {
    static func online() -> [CGDirectDisplayID] {
        var n: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &n) == .success, n > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(n))
        guard CGGetOnlineDisplayList(n, &ids, &n) == .success else { return [] }
        return Array(ids.prefix(Int(n)))
    }

    static func onlineBuiltin() -> CGDirectDisplayID? {
        online().first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func externals() -> [CGDirectDisplayID] {
        online().filter { CGDisplayIsBuiltin($0) == 0 }
    }

    /// Built-in ID even when offline: CGDisplayIsBuiltin still answers for disabled IDs.
    static func builtinID() -> CGDirectDisplayID? {
        if let id = onlineBuiltin() { return id }
        return (1...64).map { CGDirectDisplayID($0) }.first { CGDisplayIsBuiltin($0) == 1 }
    }

    static var builtinOn: Bool { onlineBuiltin() != nil }

    @discardableResult
    static func setBuiltin(_ enabled: Bool) -> Bool {
        guard let id = builtinID() else { NSLog("Clammr: built-in display not found"); return false }
        var cfg: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&cfg) == .success, let c = cfg else { return false }
        let err = CGSConfigureDisplayEnabled(c, id, enabled)
        guard err == .success else {
            CGCancelDisplayConfiguration(c)
            NSLog("Clammr: CGSConfigureDisplayEnabled error %d", err.rawValue)
            return false
        }
        return CGCompleteDisplayConfiguration(c, .forSession) == .success
    }
}

// MARK: - Switch row (menu item view, BetterDisplay-style)

final class SwitchRowView: NSView {
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "Built-in Display")
    private let subtitle = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()

    init(target: AnyObject, action: Selector) {
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 44))

        icon.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: 18, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor

        title.font = .menuFont(ofSize: 0)
        subtitle.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitle.textColor = .secondaryLabelColor

        toggle.controlSize = .small
        toggle.target = target
        toggle.action = action

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1

        let row = NSStackView(views: [icon, labels, NSView(), toggle])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(on: Bool, externals: Int) {
        toggle.state = on ? .on : .off
        // Can't switch off without an external display; can always switch back on.
        toggle.isEnabled = !(on && externals == 0)
        icon.image = NSImage(systemSymbolName: on ? "laptopcomputer" : "laptopcomputer.slash",
                             accessibilityDescription: nil)
        let ext = "\(externals) external display\(externals == 1 ? "" : "s")"
        subtitle.stringValue = on && externals == 0 ? "Connect an external display first" : "\(on ? "On" : "Off") · \(ext)"
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var wantOff = false
    private var pending: DispatchWorkItem?
    private var signalSources: [DispatchSourceSignal] = []
    private weak var switchRow: SwitchRowView?

    private var keepOff: Bool {
        get { UserDefaults.standard.object(forKey: "keepOff") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepOff") }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshIcon()

        let me = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback({ _, flags, ctx in
            guard !flags.contains(.beginConfigurationFlag), let ctx else { return }
            let app = Unmanaged<AppDelegate>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { app.scheduleReconcile() }
        }, me)

        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            s.setEventHandler { NSApp.terminate(nil) }
            s.resume()
            signalSources.append(s)
        }
    }

    func applicationWillTerminate(_ note: Notification) {
        if wantOff && !Displays.builtinOn { Displays.setBuiltin(true) }
    }

    // MARK: display change handling

    private func scheduleReconcile() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func reconcile() {
        let externals = Displays.externals()
        if !Displays.builtinOn && externals.isEmpty {
            Displays.setBuiltin(true)          // HDMI unplugged: never leave user with no screen
            wantOff = false
        } else if wantOff && keepOff && Displays.builtinOn && !externals.isEmpty {
            Displays.setBuiltin(false)         // macOS re-enabled panel after wake/lid
        }
        refreshIcon()
    }

    private func refreshIcon() {
        let on = Displays.builtinOn
        switchRow?.update(on: on, externals: Displays.externals().count)
        let img = NSImage(systemSymbolName: on ? "laptopcomputer" : "laptopcomputer.slash",
                          accessibilityDescription: on ? "Built-in display on" : "Built-in display off")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // MARK: menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let on = Displays.builtinOn
        let ext = Displays.externals().count

        let header = NSMenuItem(title: "Clammr \(appVersion)", action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(string: "Clammr \(appVersion)",
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)])
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let row = NSMenuItem()
        let view = SwitchRowView(target: self, action: #selector(switchChanged(_:)))
        view.update(on: on, externals: ext)
        row.view = view
        switchRow = view
        menu.addItem(row)
        menu.addItem(.separator())

        let keep = NSMenuItem(title: "Keep Off After Wake/Reconnect", action: #selector(toggleKeepOff), keyEquivalent: "")
        keep.target = self
        keep.state = keepOff ? .on : .off
        menu.addItem(keep)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Clammr", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let gh = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        gh.target = self
        menu.addItem(gh)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit (restores display)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func switchChanged(_ sender: NSSwitch) {
        if sender.state == .off {
            if Displays.builtinOn && !Displays.externals().isEmpty {
                wantOff = Displays.setBuiltin(false)
            }
        } else if !Displays.builtinOn {
            Displays.setBuiltin(true)
            wantOff = false
        }
        refreshIcon()
    }

    @objc private func toggleKeepOff() { keepOff.toggle() }

    @objc private func openGitHub() { NSWorkspace.shared.open(repoURL) }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "Clamshell mode without closing the lid.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(string: repoURL.absoluteString.replacingOccurrences(of: "https://", with: ""),
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .link: repoURL]))
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        credits.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: credits.length))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Clammr",
            .applicationIcon: NSImage(systemSymbolName: "laptopcomputer.slash", accessibilityDescription: nil) as Any,
            .credits: credits,
        ])
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login failed"
            alert.informativeText = "\(error.localizedDescription)\nAdd Clammr manually in System Settings → General → Login Items."
            alert.runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
