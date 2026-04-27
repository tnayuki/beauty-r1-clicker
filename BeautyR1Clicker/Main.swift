import Carbon.HIToolbox
import CoreGraphics
import Darwin
import Foundation
import IOKit
import IOKit.hid

/// Menu-bar resident app that turns the Beauty-R1 BLE clicker into a virtual arrow-key emitter.
/// On contact, the (X, Y) reported by the device is matched to the nearest measured anchor
/// (up/down/left/right) and the corresponding arrow key is posted via CGEvent.
@main
enum BeautyR1ClickerApp {
    static func main() {
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        let ctx = BeautyR1Context()
        let ctxPtr = Unmanaged.passRetained(ctx).toOpaque()
        let manager = startHIDManager(ctxPtr: ctxPtr)

        MenuBarController.run(ctx: ctx, manager: manager)
    }
}

// MARK: - Beauty-R1 constants

enum BeautyR1 {
    /// Product-name filter (case-insensitive substring match against kIOHIDProductKey).
    static let productNameContains = "beauty-r1"
    /// Display name shown in the menu bar UI.
    static let displayName = "Beauty-R1"

    /// Measured (X, Y) values reported right after contact for each direction button.
    /// The button whose anchor is the nearest neighbor (within `earlyMaxDistSq`) wins.
    static let anchorUp = (x: 1264, y: 752)
    static let anchorDown = (x: 1264, y: 2552)
    static let anchorLeft = (x: 314, y: 1616)
    static let anchorRight = (x: 1360, y: 1616)
    static let earlyMaxDistSq: Int = 280_000
}

// MARK: - Device info

func deviceMatches(_ d: IOHIDDevice) -> Bool {
    let p = (IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "")
        .lowercased()
    return p.contains(BeautyR1.productNameContains)
}

func devLabel(_ d: IOHIDDevice) -> String {
    func s(_ k: String) -> String? { IOHIDDeviceGetProperty(d, k as CFString) as? String }
    let product = s(kIOHIDProductKey) ?? "?"
    let mfg = s(kIOHIDManufacturerKey) ?? "?"
    let trans = s(kIOHIDTransportKey) ?? "?"
    let vid = (IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? NSNumber)
        .map { String(format: "0x%04X", $0.uint32Value) } ?? "?"
    let pid = (IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? NSNumber)
        .map { String(format: "0x%04X", $0.uint32Value) } ?? "?"
    return "[\(mfg) / \(product)] \(trans) vid=\(vid) pid=\(pid)"
}

// MARK: - Context

enum Direction { case up, down, left, right }

final class BeautyR1Context {
    /// Number of currently connected devices that match the Beauty-R1 product filter.
    var matchingDeviceCount: Int = 0
    /// Invoked on connect/disconnect (called from the IOKit callback thread).
    /// Used to refresh the menu-bar UI.
    var onDeviceChange: (() -> Void)?
    /// Invoked right after a synthetic key has been posted (called from the IOKit callback thread).
    /// Used to flash the menu-bar icon as a press indicator.
    var onSyntheticKeyEmit: ((Direction) -> Void)?

    /// Last plausible X / Y observed outside of an active gesture.
    /// Beauty-R1 emits X / Y in the same report as tip=1, but for the Right button Y is
    /// sometimes not refreshed, so we carry the last value across gestures and reuse it
    /// in `startGesture` to make the early-anchor decision.
    private var pendingX: Int?
    private var pendingY: Int?

    private var inGesture = false
    /// Whether a synthetic key has already been emitted for the current contact.
    private var gestureKeySent = false
    private var earlyX: Int?
    private var earlyY: Int?

    init() {
        // Preset to anchor centers so the very first press after launch can also resolve
        // via the early-anchor path (X uses the up anchor, Y uses the left anchor).
        pendingX = BeautyR1.anchorUp.x
        pendingY = BeautyR1.anchorLeft.y
    }

    func startGesture() {
        inGesture = true
        gestureKeySent = false
        earlyX = nil; earlyY = nil
        if let p = pendingX, isPlausibleAxis(p) { earlyX = p }
        if let p = pendingY, isPlausibleAxis(p) { earlyY = p }
        _ = tryEarlyEmit()
    }

    /// End of contact. The early decision has already fired (if any), so we only clear
    /// per-gesture state. `pendingX` / `pendingY` are kept for the next early decision.
    func endGesture() {
        inGesture = false
        gestureKeySent = false
        earlyX = nil; earlyY = nil
    }

    func recordX(_ v: Int) {
        if !inGesture, isPlausibleAxis(v) { pendingX = v }
        guard inGesture else { return }
        if isPlausibleAxis(v), earlyX == nil { earlyX = v }
        _ = tryEarlyEmit()
    }

    func recordY(_ v: Int) {
        if !inGesture, isPlausibleAxis(v) { pendingY = v }
        guard inGesture else { return }
        if isPlausibleAxis(v), earlyY == nil { earlyY = v }
        _ = tryEarlyEmit()
    }

    private func isPlausibleAxis(_ v: Int) -> Bool { v >= 0 && v < 20_000 }

    @discardableResult
    private func tryEarlyEmit() -> Bool {
        guard inGesture, !gestureKeySent else { return false }
        guard let dir = directionFromAnchor() else { return false }
        postSyntheticKey(directionKey(for: dir))
        onSyntheticKeyEmit?(dir)
        gestureKeySent = true
        return true
    }

    private func directionFromAnchor() -> Direction? {
        guard let ex = earlyX, let ey = earlyY,
              isPlausibleAxis(ex), isPlausibleAxis(ey) else { return nil }
        let cands: [(Direction, Int, Int)] = [
            (.up, BeautyR1.anchorUp.x, BeautyR1.anchorUp.y),
            (.down, BeautyR1.anchorDown.x, BeautyR1.anchorDown.y),
            (.left, BeautyR1.anchorLeft.x, BeautyR1.anchorLeft.y),
            (.right, BeautyR1.anchorRight.x, BeautyR1.anchorRight.y)
        ]
        var best: Direction?
        var bestD = Int.max
        for (d, ax, ay) in cands {
            let dist = (ex - ax) * (ex - ax) + (ey - ay) * (ey - ay)
            if dist < bestD { bestD = dist; best = d }
        }
        return bestD <= BeautyR1.earlyMaxDistSq ? best : nil
    }

    private func directionKey(for d: Direction) -> CGKeyCode {
        switch d {
        case .up: return CGKeyCode(kVK_UpArrow)
        case .down: return CGKeyCode(kVK_DownArrow)
        case .left: return CGKeyCode(kVK_LeftArrow)
        case .right: return CGKeyCode(kVK_RightArrow)
        }
    }
}

// MARK: - HID manager

private let kPageGeneric: UInt32 = 0x01
/// Beauty-R1 BLE reports come in on usagePage = 0x0D (Digitizer).
private let kPageDigitizer: UInt32 = 0x0D

private func startHIDManager(ctxPtr: UnsafeMutableRawPointer) -> IOHIDManager {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(bitPattern: 0))
    IOHIDManagerSetDeviceMatching(manager, nil)
    IOHIDManagerRegisterInputValueCallback(manager, inputValueCallback, ctxPtr)
    IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceConnectCallback, ctxPtr)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemoveCallback, ctxPtr)
    IOHIDManagerScheduleWithRunLoop(
        manager,
        CFRunLoopGetCurrent(),
        CFRunLoopMode.defaultMode.rawValue
    )
    let r = IOHIDManagerOpen(manager, IOOptionBits(bitPattern: 0))
    if r != kIOReturnSuccess {
        // Most commonly kIOReturnNotPermitted when Input Monitoring is not granted.
        // Stay alive so the menu bar UI is reachable; the OS prompt will appear on
        // first IOHIDDeviceOpen attempt, and the user can relaunch after granting.
        fputs("IOHIDManagerOpen failed: 0x\(String(r, radix: 16))\n", stderr)
    }
    return manager
}

private let inputValueCallback: IOHIDValueCallback = { context, result, _, value in
    guard result == kIOReturnSuccess, let p = context else { return }
    let c = Unmanaged<BeautyR1Context>.fromOpaque(p).takeUnretainedValue()
    let element = IOHIDValueGetElement(value)
    let dev = IOHIDElementGetDevice(element)
    guard deviceMatches(dev) else { return }
    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intValue = IOHIDValueGetIntegerValue(value)

    if usagePage == kPageDigitizer, usage == 0x42 {
        if intValue > 0 {
            c.startGesture()
        } else {
            c.endGesture()
        }
        return
    }

    if usagePage == kPageGeneric {
        if usage == 0x30 {
            c.recordX(Int(intValue))
        } else if usage == 0x31 {
            c.recordY(Int(intValue))
        }
    }
}

private let deviceConnectCallback: IOHIDDeviceCallback = { context, result, _, device in
    guard result == kIOReturnSuccess, let context else { return }
    let c = Unmanaged<BeautyR1Context>.fromOpaque(context).takeUnretainedValue()
    guard deviceMatches(device) else { return }
    c.matchingDeviceCount += 1
    c.onDeviceChange?()
}

private let deviceRemoveCallback: IOHIDDeviceCallback = { context, result, _, device in
    guard result == kIOReturnSuccess, let context else { return }
    let c = Unmanaged<BeautyR1Context>.fromOpaque(context).takeUnretainedValue()
    guard deviceMatches(device) else { return }
    if c.matchingDeviceCount > 0 { c.matchingDeviceCount -= 1 }
    c.onDeviceChange?()
}

private func postSyntheticKey(_ key: CGKeyCode) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
    else { return }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
}
