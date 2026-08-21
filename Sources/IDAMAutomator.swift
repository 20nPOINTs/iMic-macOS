import Foundation
import ApplicationServices
import AppKit

class PermissionsManager {
    static let shared = PermissionsManager()
    
    func checkAndRequestAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        return isTrusted
    }
}

class IDAMAutomator {
    static let shared = IDAMAutomator()
    
    private var isExecuting = false
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleTrigger), name: .triggerIDAM, object: nil)
    }
    
    @objc private func handleTrigger() {
        print("[IDAM] handleTrigger invoked!")
        guard !isExecuting else {
            print("[IDAM] Ignored, already executing.")
            return
        }
        
        // Feat 2: Check if IDAM automation is enabled
        guard AudioEngine.shared.appState?.autoIDAMEnabled != false else {
            print("[IDAM] IDAM automation disabled by user.")
            return
        }
        
        if !PermissionsManager.shared.checkAndRequestAccessibility() {
            print("[IDAM] Accessibility permission denied.")
            return
        }
        
        isExecuting = true
        print("[IDAM] Executing iPad activation...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.enableIPadInAudioMidiSetup {
                // Switch input to iPad via audio_switcher equivalent in Swift
                self.setIPadAsInput()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                    self.isExecuting = false // Cooldown 8 seconds
                    print("[IDAM] Cooldown finished.")
                }
            }
        }
    }
    
    private func enableIPadInAudioMidiSetup(completion: @escaping () -> Void) {
        let bundleID = "com.apple.audio.AudioMIDISetup"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let wasRunning = !runningApps.isEmpty
        
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        if !wasRunning {
            config.hides = true
        }
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            let scriptSource = """
            tell application "System Events"
                if exists (process "Audio MIDI Setup") then
                    tell process "Audio MIDI Setup"
                        set clicked to false
                        repeat 15 times
                            repeat with w in windows
                                try
                                    set o to outline 1 of scroll area 1 of splitter group 1 of w
                                    repeat with r in rows of o
                                        repeat with u in UI elements of r
                                            repeat with b in buttons of u
                                                set bTitle to title of b as string
                                                if bTitle is "Enable" or bTitle is "활성화" then
                                                    click b
                                                    set clicked to true
                                                    exit repeat
                                                end if
                                            end repeat
                                            if clicked then exit repeat
                                        end repeat
                                        if clicked then exit repeat
                                    end repeat
                                end try
                                if clicked then exit repeat
                            end repeat
                            if clicked then exit repeat
                            delay 0.2
                        end repeat
                    end tell
                end if
            end tell
            
            if not \(wasRunning) then
                tell application "Audio MIDI Setup" to quit
            end if
            """
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", scriptSource]
            
            print("[IDAM] Running AppleScript via osascript to click Enable in Audio MIDI Setup...")
            do {
                try process.run()
                process.waitUntilExit()
                print("[IDAM] AppleScript executed via osascript successfully. wasRunning=\(wasRunning)")
            } catch {
                print("[IDAM] Failed to compile or run AppleScript via osascript: \(error)")
            }
            completion()
        }
    }
    
    private func setIPadAsInput() {
        print("[IDAM] Setting iPad as input natively...")
        // Call AudioEngine directly
        // Delay slightly to give CoreAudio time to register the newly enabled iPad audio device
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioEngine.shared.setInputToIPad()
        }
    }
}
