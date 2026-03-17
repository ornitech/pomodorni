import Foundation
import UserNotifications

final class NotificationService {
    private let provider: NotificationProvider
    private(set) var isAuthorized = false

    init(provider: NotificationProvider = SystemNotificationProvider()) {
        self.provider = provider
    }

    func requestPermission() async -> Bool {
        isAuthorized = await provider.requestAuthorization()
        return isAuthorized
    }

    func checkPermission() async {
        isAuthorized = await provider.checkAuthorizationStatus()
    }

    func notifySessionComplete(_ sessionType: SessionType) {
        let (title, body): (String, String) = switch sessionType {
        case .work:
            ("Work session complete!", "Time for a break.")
        case .shortBreak, .longBreak:
            ("Break's over!", "Ready to focus?")
        }
        provider.send(title: title, body: body)
    }
}

final class SystemNotificationProvider: NotificationProvider {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func checkAuthorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
