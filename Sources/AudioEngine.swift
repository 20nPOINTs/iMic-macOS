import Foundation
import CoreAudio

// MARK: - Microphone Categories & Strict Sorting Order
enum MicCategory: Int, Comparable {
    case ipad = 1
    case iphone = 2
    case builtIn = 3
    case external = 4
    case other = 5
    
    static func < (lhs: MicCategory, rhs: MicCategory) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var icon: String {
        switch self {
        case .ipad: return "📱 "
        case .iphone: return "📱 "
        case .builtIn: return "💻 "
        case .external: return "🎙️ "
        case .other: return "🔊 "
        }
    }
}

class AudioEngine {
    static let shared = AudioEngine()
    var appState: AppState?
    
    private var outputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var inputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    private var devicesAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    // MARK: - Debounce timer
    private var debounceWork: DispatchWorkItem?
    
    func startMonitoring(appState: AppState) {
        self.appState = appState
        updateState()
        
        AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &outputAddr, DispatchQueue.main) { _, _ in
            self.scheduleUpdate()
        }
        
        AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &inputAddr, DispatchQueue.main) { _, _ in
            self.scheduleUpdate()
        }
        
        AudioObjectAddPropertyListenerBlock(UInt32(kAudioObjectSystemObject), &devicesAddr, DispatchQueue.main) { _, _ in
            self.scheduleUpdate()
        }
    }
    
    private func scheduleUpdate() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.updateState()
        }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    
    func updateState() {
        DispatchQueue.main.async {
            let outputDeviceID = self.getDefaultDevice(isInput: false)
            let inputDeviceID = self.getDefaultDevice(isInput: true)
            let outputName = self.getDeviceName(deviceID: outputDeviceID)
            let inputName = self.getDeviceName(deviceID: inputDeviceID)
            
            self.appState?.currentOutput = outputName
            self.appState?.currentInput = inputName
            
            // Refresh real-time available input devices list
            self.appState?.availableInputDevices = self.getCategorizedInputDevices(excludingBTOutputName: outputName)
            
            let isBTHeadsetOut = self.isBluetooth(deviceID: outputDeviceID)
            let isIDAMIn = inputName.lowercased().contains("ipad") || inputName.lowercased().contains("iphone")
            
            self.appState?.isBTHeadsetActive = isBTHeadsetOut
            self.appState?.isIpadActive = isIDAMIn
            
            // High quality is maintained when output is not BT headset or input is a non-BT high quality mic
            let isBTHeadsetIn = self.isBluetooth(deviceID: inputDeviceID)
            self.appState?.isHighQuality = !isBTHeadsetOut || (!isBTHeadsetIn && inputDeviceID != kAudioObjectUnknown)
            
            // Guard — skip switching if auto-switch is disabled
            guard self.appState?.autoSwitchEnabled != false else {
                print("[AudioEngine] Auto-switch disabled, skipping.")
                return
            }
            
            if isBTHeadsetOut {
                self.performSmartSwitch(btOutputName: outputName)
            }
        }
    }
    
    // MARK: - Smart Microphone Switching
    
    private func performSmartSwitch(btOutputName: String) {
        // 1. User has explicitly chosen a specific preferred mic
        if let preferredUID = appState?.preferredMicUID,
           let preferredID = findDeviceByUID(uid: preferredUID, isInput: true) {
            setDefaultInput(deviceID: preferredID)
            let name = getDeviceName(deviceID: preferredID)
            print("[AudioEngine] Switched to user-preferred mic: \(name) (UID: \(preferredUID))")
            return
        }
        
        // 2. Auto (Smart Detection) Mode: Order = iPad -> iPhone -> External -> Built-in -> Fallback
        if let ipadID = findDeviceID(matching: "ipad", isInput: true) {
            setDefaultInput(deviceID: ipadID)
            print("[AudioEngine] Auto: Switched to iPad (Device ID: \(ipadID))")
            return
        }
        
        if let iphoneID = findDeviceID(matching: "iphone", isInput: true) {
            setDefaultInput(deviceID: iphoneID)
            print("[AudioEngine] Auto: Switched to iPhone (Device ID: \(iphoneID))")
            return
        }
        
        // If iPad or iPhone is connected via USB but IDAM is not yet enabled
        if USBMonitor.shared.isIDAMDeviceConnected() {
            print("[AudioEngine] Auto: IDAM USB device detected. Triggering IDAM...")
            NotificationCenter.default.post(name: .triggerIDAM, object: nil)
            return
        }
        
        // Check for External USB/Thunderbolt mic (excluding the BT headset itself)
        if let externalID = findExternalMicID(excludingBTName: btOutputName) {
            setDefaultInput(deviceID: externalID)
            print("[AudioEngine] Auto: Switched to External mic: \(getDeviceName(deviceID: externalID))")
            return
        }
        
        // Check for Built-in Mac mic
        if let builtInID = findBuiltInMicID() {
            setDefaultInput(deviceID: builtInID)
            print("[AudioEngine] Auto: Switched to Built-in mic: \(getDeviceName(deviceID: builtInID))")
            return
        }
        
        // Fallback to BT headset mic if nothing else is available
        fallbackToBTMic(btOutputName: btOutputName)
    }
    
    private func fallbackToBTMic(btOutputName: String) {
        let currentInputName = getDeviceName(deviceID: getDefaultDevice(isInput: true))
        let btLower = btOutputName.lowercased()
        if !currentInputName.lowercased().contains(btLower.prefix(6)) {
            if let btInputID = findDeviceID(matching: String(btLower.prefix(8)), isInput: true) {
                setDefaultInput(deviceID: btInputID)
                print("[AudioEngine] Fallback: Set input to BT headset mic: \(getDeviceName(deviceID: btInputID))")
            }
        }
    }
    
    // MARK: - Device Categorization for UI
    
    func getCategorizedInputDevices(excludingBTOutputName: String = "") -> [(name: String, uid: String, category: MicCategory)] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: deviceCount)
        AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        
        var result: [(name: String, uid: String, category: MicCategory)] = []
        for deviceID in deviceIDs {
            if hasInputStreams(deviceID: deviceID) {
                let name = getDeviceName(deviceID: deviceID)
                let uid = getDeviceUID(deviceID: deviceID)
                let lowerName = name.lowercased()
                
                // Exclude Bluetooth output headset's own mic to keep the list clean
                if isBluetooth(deviceID: deviceID) {
                    continue
                }
                
                guard !uid.isEmpty else { continue }
                
                let transport = getTransportType(deviceID: deviceID)
                let category: MicCategory
                
                if lowerName.contains("ipad") {
                    category = .ipad
                } else if lowerName.contains("iphone") {
                    category = .iphone
                } else if transport == kAudioDeviceTransportTypeBuiltIn || lowerName.contains("내장") || lowerName.contains("built-in") {
                    category = .builtIn
                } else if transport == kAudioDeviceTransportTypeUSB || transport == kAudioDeviceTransportTypeThunderbolt || transport == kAudioDeviceTransportTypePCI {
                    category = .external
                } else {
                    category = .other
                }
                
                result.append((name: name, uid: uid, category: category))
            }
        }
        
        // Strict order: iPad (1) -> iPhone (2) -> Built-in (3) -> External (4) -> Other (5)
        return result.sorted { $0.category < $1.category }
    }
    
    // MARK: - CoreAudio Transport & Search Helpers
    
    private func isBluetooth(deviceID: AudioObjectID) -> Bool {
        guard deviceID != kAudioObjectUnknown else { return false }
        return getTransportType(deviceID: deviceID) == kAudioDeviceTransportTypeBluetooth
    }
    
    private func getTransportType(deviceID: AudioObjectID) -> UInt32 {
        guard deviceID != kAudioObjectUnknown else { return 0 }
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        return status == noErr ? transportType : 0
    }
    
    private func findExternalMicID(excludingBTName: String) -> AudioObjectID? {
        for (_, uid, category) in getCategorizedInputDevices(excludingBTOutputName: excludingBTName) {
            if category == .external {
                return findDeviceByUID(uid: uid, isInput: true)
            }
        }
        return nil
    }
    
    private func findBuiltInMicID() -> AudioObjectID? {
        for (_, uid, category) in getCategorizedInputDevices() {
            if category == .builtIn {
                return findDeviceByUID(uid: uid, isInput: true)
            }
        }
        return nil
    }
    
    private func getDefaultDevice(isInput: Bool) -> AudioObjectID {
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: isInput ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }
    
    func findDeviceID(matching query: String, isInput: Bool) -> AudioObjectID? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: deviceCount)
        AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        
        for deviceID in deviceIDs {
            let name = getDeviceName(deviceID: deviceID).lowercased()
            if name.contains(query.lowercased()) {
                if !isInput || hasInputStreams(deviceID: deviceID) {
                    return deviceID
                }
            }
        }
        return nil
    }
    
    func findDeviceByUID(uid: String, isInput: Bool) -> AudioObjectID? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyDataSize(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size)
        let deviceCount = Int(size) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: deviceCount)
        AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs)
        
        for deviceID in deviceIDs {
            let deviceUID = getDeviceUID(deviceID: deviceID)
            if deviceUID == uid {
                if !isInput || hasInputStreams(deviceID: deviceID) {
                    return deviceID
                }
            }
        }
        return nil
    }
    
    func getDeviceUID(deviceID: AudioObjectID) -> String {
        if deviceID == kAudioObjectUnknown { return "" }
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
        if status == noErr, let uidUnmanaged = uid {
            return uidUnmanaged.takeRetainedValue() as String
        }
        return ""
    }
    
    private func hasInputStreams(deviceID: AudioObjectID) -> Bool {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }
    
    func setDefaultInput(deviceID: AudioObjectID) {
        var newDeviceID = deviceID
        let size = UInt32(MemoryLayout<AudioObjectID>.size)
        var setAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(UInt32(kAudioObjectSystemObject), &setAddress, 0, nil, size, &newDeviceID)
    }
    
    func setInputToIPad(retryCount: Int = 6) {
        if let ipadID = findDeviceID(matching: "ipad", isInput: true) {
            setDefaultInput(deviceID: ipadID)
            print("[AudioEngine] Successfully set input to iPad (Device ID: \(ipadID))")
            return
        }
        
        if retryCount > 0 {
            print("[AudioEngine] iPad device not registered yet, retrying in 0.5s... (Remaining: \(retryCount))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setInputToIPad(retryCount: retryCount - 1)
            }
        } else {
            print("[AudioEngine] iPad audio device not found after retries. Falling back...")
            self.performSmartSwitch(btOutputName: getDeviceName(deviceID: getDefaultDevice(isInput: false)))
        }
    }
    
    func getDeviceName(deviceID: AudioObjectID) -> String {
        if deviceID == kAudioObjectUnknown { return "알 수 없음" }
        
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        if status == noErr, let nameUnmanaged = name {
            return nameUnmanaged.takeRetainedValue() as String
        }
        return "알 수 없음"
    }
}
