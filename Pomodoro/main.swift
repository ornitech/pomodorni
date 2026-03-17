import AppKit

// delegate must be a global variable — NSApplication.delegate is weak,
// so a local variable would be deallocated by ARC
let delegate = AppDelegate()

let app = NSApplication.shared
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
