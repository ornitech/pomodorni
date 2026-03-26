import Foundation

protocol ActivityProvider: AnyObject {
    func startMonitoring(onActivity: @escaping () -> Void)
    func stopMonitoring()
}
