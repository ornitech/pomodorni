import Foundation

protocol SoundProvider: AnyObject {
    func play(systemSound name: String)
}
