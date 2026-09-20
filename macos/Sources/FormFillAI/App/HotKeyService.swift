import AppKit
import Carbon.HIToolbox
import Foundation

/// グローバルショートカット。初期値は Option + Space。
///
/// Carbon の RegisterEventHotKey を使う。CGEventTap と違い、
/// 他アプリが前面のままでも確実に届く。
public enum HotKeyDefaults {
    /// Option + Space。
    public static let keyCode = UInt32(kVK_Space)
    public static let modifiers = UInt32(optionKey)
}

@MainActor
public final class HotKeyService {

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    private static let signature: OSType = {
        let chars = Array("JVFL".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    public init() {}

    public func register(
        keyCode: UInt32 = HotKeyDefaults.keyCode,
        modifiers: UInt32 = HotKeyDefaults.modifiers,
        handler: @escaping () -> Void
    ) {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard hotKeyID.signature == HotKeyService.signature else { return noErr }
                let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { service.handler?() }
                return noErr
            },
            1, &eventType, selfPointer, &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        handler = nil
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
