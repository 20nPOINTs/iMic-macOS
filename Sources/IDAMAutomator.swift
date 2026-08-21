import Foundation
import AppKit

class IDAMAutomator {
    static let shared = IDAMAutomator()
    var appState: AppState?
    
    private var isActivating = false
    private let bundleID = "com.apple.audio.AudioMIDISetup"
    
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
        
        // Rule 1: Check if Audio MIDI Setup was already open by the user
        let wasAlreadyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        print("[IDAMAutomator] Triggering IDAM. Was Audio MIDI Setup already running? \(wasAlreadyRunning)")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // If not running, launch quietly in background without stealing focus
            if !wasAlreadyRunning {
                let url = URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                config.hides = true
                
                let sema = DispatchSemaphore(value: 0)
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                    sema.signal()
                }
                _ = sema.wait(timeout: .now() + 1.0)
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // Click Enable / 활성화 button
            let clickScript = """
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
            """
            
            let appleScript = NSAppleScript(source: clickScript)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            
            if let error = error {
                print("[IDAMAutomator] Click script error: \(error)")
            } else {
                print("[IDAMAutomator] Successfully sent Enable click.")
            }
            
            // Rule 2: Only quit if it was NOT already open by the user!
            if !wasAlreadyRunning {
                Thread.sleep(forTimeInterval: 0.3)
                let quitScript = NSAppleScript(source: "tell application \"Audio MIDI Setup\" to quit")
                quitScript?.executeAndReturnError(nil)
                print("[IDAMAutomator] Closed background Audio MIDI Setup.")
            } else {
                print("[IDAMAutomator] Preserved user-opened Audio MIDI Setup window.")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.isActivating = false
                AudioEngine.shared.setInputToIPad()
            }
        }
    }
}
