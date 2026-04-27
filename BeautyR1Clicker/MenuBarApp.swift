import AppKit
import Foundation
import IOKit
import IOKit.hid

// MARK: - Localization (BeautyR1Clicker/<lang>.lproj/Localizable.strings)
private enum L10n {
    private static let table = "Localizable"

    private static func tr(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: table)
    }

    static var starting: String { tr("menu_starting") }
    static var devices: String { tr("menu_devices") }
    static var none: String { tr("menu_none") }

    static func statusConnected(_ name: String, _ count: Int) -> String {
        String(format: tr("status_connected"), name, count)
    }

    static func statusDisconnected(_ name: String) -> String {
        String(format: tr("status_disconnected"), name)
    }

    static func quit(_ appName: String) -> String {
        String(format: tr("menu_quit"), appName)
    }
}

/// Menu-bar resident UI. The icon is shown in full opacity when a Beauty-R1 is connected
/// and dimmed (translucent) otherwise.
@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private let ctx: BeautyR1Context
    private let manager: IOHIDManager
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var devicesSubmenuItem: NSMenuItem!
    private var devicesSubmenu: NSMenu!
    private var flashEndWork: DispatchWorkItem?

    private static let appDisplayName = "\(BeautyR1.displayName) Clicker"

    init(ctx: BeautyR1Context, manager: IOHIDManager) {
        self.ctx = ctx
        self.manager = manager
    }

    /// Does not return; blocks inside NSApp.run().
    static func run(ctx: BeautyR1Context, manager: IOHIDManager) {
        let controller = MenuBarController(ctx: ctx, manager: manager)
        // NSApplication.delegate is a weak reference, so retain the controller manually
        // to keep it alive for the lifetime of the process.
        _ = Unmanaged.passRetained(controller)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)  // No Dock icon; menu bar only.
        app.delegate = controller
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = ClickerStatusIcon.makeTemplateImage()
            btn.contentTintColor = nil
            btn.toolTip = Self.appDisplayName
            btn.setAccessibilityTitle(Self.appDisplayName)
        }

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: L10n.starting, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        devicesSubmenuItem = NSMenuItem(title: L10n.devices, action: nil, keyEquivalent: "")
        devicesSubmenu = NSMenu()
        devicesSubmenuItem.submenu = devicesSubmenu
        menu.addItem(devicesSubmenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: L10n.quit(Self.appDisplayName),
            action: #selector(handleQuit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        // IOKit's HID callbacks may fire on a non-main thread, so any UI update is
        // bounced back to the main queue here.
        ctx.onDeviceChange = { [weak self] in
            DispatchQueue.main.async { self?.updateUI() }
        }
        ctx.onSyntheticKeyEmit = { [weak self] dir in
            DispatchQueue.main.async { self?.flashKeyPress(dir) }
        }

        updateUI()
    }

    @objc private func handleQuit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func applyStatusBarButtonAlpha() {
        let connected = ctx.matchingDeviceCount > 0
        statusItem?.button?.alphaValue = connected ? 1.0 : 0.35
    }

    /// Briefly switches the icon to the "active" (heavier) variant for ~0.12s as a
    /// visual confirmation that a synthetic key was emitted.
    private func flashKeyPress(_ dir: Direction) {
        guard let btn = statusItem?.button else { return }
        btn.image = ClickerStatusIcon.makeActiveTemplateImage(direction: dir)
        applyStatusBarButtonAlpha()

        flashEndWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.endKeyPressFlash()
        }
        flashEndWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func endKeyPressFlash() {
        flashEndWork = nil
        statusItem?.button?.image = ClickerStatusIcon.makeTemplateImage()
        applyStatusBarButtonAlpha()
    }

    private func updateUI() {
        if let btn = statusItem.button, flashEndWork == nil {
            btn.image = ClickerStatusIcon.makeTemplateImage()
        }
        applyStatusBarButtonAlpha()

        let connected = ctx.matchingDeviceCount > 0
        statusMenuItem.title = connected
            ? L10n.statusConnected(BeautyR1.displayName, ctx.matchingDeviceCount)
            : L10n.statusDisconnected(BeautyR1.displayName)

        devicesSubmenu.removeAllItems()
        if let all = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            let list = Array(all)
                .filter(deviceMatches)
                .sorted { devLabel($0) < devLabel($1) }
            if list.isEmpty {
                let it = NSMenuItem(title: L10n.none, action: nil, keyEquivalent: "")
                it.isEnabled = false
                devicesSubmenu.addItem(it)
            } else {
                for d in list {
                    let it = NSMenuItem(title: devLabel(d), action: nil, keyEquivalent: "")
                    it.isEnabled = false
                    devicesSubmenu.addItem(it)
                }
            }
        }
        devicesSubmenuItem.isHidden = false
    }
}
