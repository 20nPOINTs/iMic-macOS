import Foundation
import AppKit

class IDAMAutomator {
    static let shared = IDAMAutomator()
    var appState: AppState?
    
    private var isActivating = false
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTrigger), name: .triggerIDAM, object: nil)
    }
    
    func startMonitoring(appState: AppState) {
        self.appState = appState
    }
    
    @objc func handleTrigger() {
        guard appState?.autoIDAMEnabled != false else {
            print("[IDAMAutomator] IDAM automation is disabled by user.")
            return
        }
        
        guard !isActivating else { return }
        isActivating = true
        
        print("[IDAMAutomator] Automatically enabling iPad/iPhone in Audio MIDI Setup...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            tell application "Audio MIDI Setup"
                activate
            end tell
            delay 0.4
            tell application "System Events"
                tell process "Audio MIDI Setup"
                    try
                        repeat with w in windows
                            try
                                set allUIs to entire contents of w
                                repeat with ui in allUIs
                                    try
                                        if (name of ui is "Enable" or title of ui is "Enable" or name of ui is "활성화" or title of ui is "활성화") and class of ui is button then
                                            click ui
                                            log "Clicked Enable button"
                                        end if
                                    end try
                                end repeat
                            end try
                        end repeat
                    end try
                end tell
            end tell
            delay 0.4
            tell application "Audio MIDI Setup" to quit
            """
            
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            
            if let error = error {
                print("[IDAMAutomator] AppleScript execution error: \(error)")
            } else {
                print("[IDAMAutomator] Successfully clicked Enable in Audio MIDI Setup.")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.isActivating = false
                AudioEngine.shared.setInputToIPad()
            }
        }
    }
}
