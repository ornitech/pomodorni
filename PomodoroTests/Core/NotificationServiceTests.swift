import Testing
import Foundation
@testable import Pomodoro

@Suite("NotificationService")
struct NotificationServiceTests {
    @Test("sends correct notification for work completion")
    func workCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.work)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Work session complete!")
        #expect(mock.sentNotifications[0].body == "Time for a break.")
    }

    @Test("sends correct notification for short break completion")
    func shortBreakCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.shortBreak)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Break's over!")
        #expect(mock.sentNotifications[0].body == "Ready to focus?")
    }

    @Test("sends correct notification for long break completion")
    func longBreakCompleteNotification() {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        service.notifySessionComplete(.longBreak)
        #expect(mock.sentNotifications.count == 1)
        #expect(mock.sentNotifications[0].title == "Break's over!")
        #expect(mock.sentNotifications[0].body == "Ready to focus?")
    }

    @Test("requests authorization")
    func requestAuth() async {
        let mock = MockNotificationProvider()
        let service = NotificationService(provider: mock)
        let granted = await service.requestPermission()
        #expect(mock.requestedAuthorization)
        #expect(granted)
    }

    @Test("handles denied authorization")
    func deniedAuth() async {
        let mock = MockNotificationProvider()
        mock.authorizationGranted = false
        let service = NotificationService(provider: mock)
        let granted = await service.requestPermission()
        #expect(!granted)
    }
}
