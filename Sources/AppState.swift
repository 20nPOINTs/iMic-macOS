import SwiftUI
import Combine
import ServiceManagement

class AppState: ObservableObject {
    @Published var currentOutput: String = "알 수 없음"
    @Published var currentInput: String = "알 수 없음"
    @Published var isBTHeadsetActive: Bool = false
    @Published var isIpadActive: Bool = false
    
    // Real-time categorized input device list
    @Published var availableInputDevices: [(name: String, uid: String, category: MicCategory)] = []
    
    // 이 상태를 UI에 표시하여 사용자가 현재 음질이 16kHz로 떨어졌는지 48kHz인지 알 수 있게 함
    @Published var isHighQuality: Bool = true 
    
    // MARK: - Automation toggles (UserDefaults-backed)
    @Published var autoSwitchEnabled: Bool {
        didSet { UserDefaults.standard.set(autoSwitchEnabled, forKey: "autoSwitchEnabled") }
    }
    @Published var autoIDAMEnabled: Bool {
        didSet { UserDefaults.standard.set(autoIDAMEnabled, forKey: "autoIDAMEnabled") }
    }
    
    // MARK: - Preferred mic (UserDefaults-backed, nil = Auto)
    @Published var preferredMicUID: String? {
        didSet { UserDefaults.standard.set(preferredMicUID, forKey: "preferredMicUID") }
    }
    
    // MARK: - Menu Bar Icon State
    
    enum MicState {
        case disconnected
        case ipad
        case iphone
        case builtIn(symbol: String)
        case external(name: String)
        case btHeadset(name: String)
    }
    
    var micState: MicState {
        let inputLower = currentInput.lowercased()
        
        if isIpadActive || inputLower.contains("ipad") {
            return .ipad
        } else if inputLower.contains("iphone") {
            return .iphone
        } else if inputLower.contains("내장") || inputLower.contains("built-in") || inputLower.contains("macbook") || inputLower.contains("imac") || inputLower.contains("mac mini") || inputLower.contains("mac studio") {
            let symbol = AppState.detectMacHardwareSymbol()
            return .builtIn(symbol: symbol)
        } else if isBTHeadsetActive && (inputLower.contains("airpod") || inputLower.contains("에어팟") || (!currentOutput.isEmpty && inputLower.contains(currentOutput.lowercased().prefix(6)))) {
            return .btHeadset(name: currentOutput)
        } else if !currentInput.isEmpty && currentInput != "알 수 없음" {
            return .external(name: currentInput)
        } else {
            return .disconnected
        }
    }
    
    var menuBarIcon: NSImage {
        switch micState {
        case .disconnected:
            return createMenuBarIcon(baseSymbol: "mic.slash.fill", badgeSymbol: nil)
        case .ipad:
            return createMenuBarIcon(baseSymbol: "mic.fill", badgeSymbol: "ipad")
        case .iphone:
            return createMenuBarIcon(baseSymbol: "mic.fill", badgeSymbol: "iphone")
        case .builtIn(let symbol):
            return createMenuBarIcon(baseSymbol: "mic.fill", badgeSymbol: symbol)
        case .external:
            return createMenuBarIcon(baseSymbol: "mic.fill", badgeSymbol: "waveform")
        case .btHeadset(let name):
            let lower = name.lowercased()
            let badge: String
            if lower.contains("airpods") || lower.contains("에어팟") {
                if lower.contains("pro") || lower.contains("프로") {
                    badge = "airpodspro"
                } else if lower.contains("max") || lower.contains("맥스") {
                    badge = "airpodsmax"
                } else {
                    badge = "airpods"
                }
            } else {
                badge = "headphones"
            }
            return createMenuBarIcon(baseSymbol: "mic.fill", badgeSymbol: badge)
        }
    }
    
    static func detectMacHardwareSymbol() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "laptopcomputer" }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model).lowercased()
        if modelString.contains("book") {
            return "laptopcomputer" // MacBook, MacBook Pro, MacBook Air
        } else if modelString.contains("imac") {
            return "desktopcomputer" // iMac
        } else if modelString.contains("mini") {
            return "macmini" // Mac mini
        } else {
            return "desktopcomputer" // Mac Studio, Mac Pro, etc.
        }
    }
    
    private func createMenuBarIcon(baseSymbol: String, badgeSymbol: String?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let baseConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let baseImg = NSImage(systemSymbolName: baseSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(baseConfig) {
            let baseRect = NSRect(x: badgeSymbol != nil ? 0 : 2, y: 1, width: 14, height: 16)
            baseImg.draw(in: baseRect)
        }
        
        if let badgeSymbol = badgeSymbol {
            let badgeConfig = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            if let badgeImg = NSImage(systemSymbolName: badgeSymbol, accessibilityDescription: nil)?.withSymbolConfiguration(badgeConfig) {
                let badgeRect = NSRect(x: 9, y: 0, width: 9, height: 9)
                badgeImg.draw(in: badgeRect)
            }
        }
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet {
            guard oldValue != launchAtLogin else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login status: \(error)")
                DispatchQueue.main.async {
                    self.launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }
    
    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "autoSwitchEnabled": true,
            "autoIDAMEnabled": true
        ])
        
        self.autoSwitchEnabled = defaults.bool(forKey: "autoSwitchEnabled")
        self.autoIDAMEnabled = defaults.bool(forKey: "autoIDAMEnabled")
        self.preferredMicUID = defaults.string(forKey: "preferredMicUID")
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
