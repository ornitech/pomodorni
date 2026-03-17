import Foundation

protocol NotificationProvider: AnyObject {
    func requestAuthorization() async -> Bool
    func send(title: String, body: String)
    func checkAuthorizationStatus() async -> Bool
}
