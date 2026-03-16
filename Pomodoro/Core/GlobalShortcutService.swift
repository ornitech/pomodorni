import Carbon
import AppKit

final class GlobalShortcutService {
    struct Shortcut: Equatable {
        let keyCode: UInt32
        let modifiers: UInt32

        static let ctrlOptionP = Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey))
        static let ctrlOptionS = Shortcut(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(controlKey | optionKey))
        static let ctrlOptionR = Shortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey))
    }

    enum Action: CaseIterable {
        case startPause
        case skip
        case reset
    }

    private var hotKeyRefs: [Action: EventHotKeyRef?] = [:]
    private var idToAction: [UInt32: Action] = [:]
    private var handler: ((Action) -> Void)?
    private var eventHandlerRef: EventHandlerRef?
    private static var instance: GlobalShortcutService?

    init() {
        GlobalShortcutService.instance = self
    }

    func register(shortcuts: [Action: Shortcut], handler: @escaping (Action) -> Void) {
        unregisterAll()
        self.handler = handler

        installCarbonHandler()

        var nextID: UInt32 = 0
        for (action, shortcut) in shortcuts {
            var hotKeyID = EventHotKeyID()
            hotKeyID.signature = OSType(0x504F4D4F) // "POMO"
            hotKeyID.id = nextID

            var hotKeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs[action] = hotKeyRef
                idToAction[nextID] = action
            }
            nextID += 1
        }
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        idToAction.removeAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
        eventHandlerRef = nil
    }

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if let action = GlobalShortcutService.instance?.idToAction[hotKeyID.id] {
                    DispatchQueue.main.async {
                        GlobalShortcutService.instance?.handler?(action)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &handlerRef
        )
        self.eventHandlerRef = handlerRef
    }

    deinit {
        unregisterAll()
    }
}
