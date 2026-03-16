import Foundation
@testable import Pomodoro

final class MockNotificationProvider: NotificationProvider {
    var authorizationGranted = true
    var requestedAuthorization = false
    var sentNotifications: [(title: String, body: String)] = []

    func requestAuthorization() async -> Bool {
        requestedAuthorization = true
        return authorizationGranted
    }

    func send(title: String, body: String) {
        sentNotifications.append((title: title, body: body))
    }

    func checkAuthorizationStatus() async -> Bool {
        return authorizationGranted
    }
}
