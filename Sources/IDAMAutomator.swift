import Foundation
import ObjectiveC
import AppKit

typealias AMDeviceRef = UnsafeMutableRawPointer
typealias AMDeviceNotificationCallback = @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Void
typealias AMDeviceNotificationSubscribeFunc = @convention(c) (
    AMDeviceNotificationCallback,
    UInt32,
    UInt32,
    UnsafeMutableRawPointer?,
    UnsafeMutablePointer<UnsafeMutableRawPointer?>
) -> Int32

typealias InitWithDeviceRefFunc = @convention(c) (AnyObject, Selector, AMDeviceRef) -> AnyObject
typealias NoArgMsgSendFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
typealias BoolMsgSendFunc = @convention(c) (AnyObject, Selector) -> Bool

private func amDeviceCallback(infoPtr: UnsafeRawPointer?, context: UnsafeMutableRawPointer?) {
    guard let infoPtr = infoPtr, let context = context else { return }
    let automator = Unmanaged<IDAMAutomator>.fromOpaque(context).takeUnretainedValue()
    automator.handleNotification(infoPtr: infoPtr)
}

class IDAMAutomator {
    static let shared = IDAMAutomator()
    
    private var appState: AppState?
    private var notificationRef: UnsafeMutableRawPointer?
    private var iDamClass: AnyClass?
    private var mobileDeviceHandle: UnsafeMutableRawPointer?
    private var connectedDevices: [AMDeviceRef: AnyObject] = [:]
    
    private let allocSel = NSSelectorFromString("alloc")
    private let initSel = NSSelectorFromString("initWithDeviceRef:")
    private let validateSel = NSSelectorFromString("validateDevice")
    private let connectSel = NSSelectorFromString("connectDevice")
    private let isEnabledSel = NSSelectorFromString("isEnabled")
    private let nameSel = NSSelectorFromString("name")
    private let actionTitleSel = NSSelectorFromString("actionButtonTitle")
    
    private var msgSend: InitWithDeviceRefFunc?
    private var noArgMsgSend: NoArgMsgSendFunc?
    private var boolMsgSend: BoolMsgSendFunc?
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleManualTrigger), name: .triggerIDAM, object: nil)
    }
    
    func startMonitoring(appState: AppState) {
        self.appState = appState
        
        // 1. Load CoreAudioKit (contains iDamDevice class)
        guard let coreAudioKit = Bundle(path: "/System/Library/Frameworks/CoreAudioKit.framework"),
              coreAudioKit.load() else {
            print("[IDAM] Failed to load CoreAudioKit")
            return
        }
        
        // 2. Load MobileDevice (handles USB mux connection to iOS devices)
        mobileDeviceHandle = dlopen("/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_NOW)
        guard let mobileDevice = mobileDeviceHandle else {
            print("[IDAM] Failed to load MobileDevice framework")
            return
        }
        
        // 3. Obtain iDamDevice Class reference
        guard let cls = objc_getClass("iDamDevice") as? AnyClass else {
            print("[IDAM] iDamDevice class not found in CoreAudioKit")
            return
        }
        self.iDamClass = cls
        
        // 4. Setup typed objc_msgSend signatures
        let objcMsgSendPtr = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend")
        self.msgSend = unsafeBitCast(objcMsgSendPtr, to: InitWithDeviceRefFunc.self)
        self.noArgMsgSend = unsafeBitCast(objcMsgSendPtr, to: NoArgMsgSendFunc.self)
        self.boolMsgSend = unsafeBitCast(objcMsgSendPtr, to: BoolMsgSendFunc.self)
        
        // 5. Subscribe to AMDevice connection/disconnection notifications (Hotplug)
        guard let sym = dlsym(mobileDevice, "AMDeviceNotificationSubscribe") else {
            print("[IDAM] Failed to resolve AMDeviceNotificationSubscribe")
            return
        }
        
        let subscribe = unsafeBitCast(sym, to: AMDeviceNotificationSubscribeFunc.self)
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = subscribe(amDeviceCallback, 0, 0, context, &notificationRef)
        print("[IDAM] Native IDAM Automator initialized! Subscription status: \(status)")
    }
    
    func handleNotification(infoPtr: UnsafeRawPointer) {
        let devPtr = infoPtr.load(as: AMDeviceRef.self)
        let msg = infoPtr.advanced(by: MemoryLayout<AMDeviceRef>.size).load(as: UInt32.self)
        
        DispatchQueue.main.async {
            switch msg {
            case 1: // ADNCI_MSG_CONNECTED (Attach / Hotplug Insert)
                self.deviceConnected(devPtr: devPtr)
            case 2: // ADNCI_MSG_DISCONNECTED (Detach / Hotplug Remove)
                self.deviceDisconnected(devPtr: devPtr)
            default:
                break
            }
        }
    }
    
    private func deviceConnected(devPtr: AMDeviceRef) {
        guard let iDamClass = iDamClass,
              let noArgMsgSend = noArgMsgSend,
              let msgSend = msgSend,
              let boolMsgSend = boolMsgSend else { return }
        
        guard let allocated = noArgMsgSend(iDamClass as AnyObject, allocSel) else { return }
        let devInstance = msgSend(allocated, initSel, devPtr)
        connectedDevices[devPtr] = devInstance
        
        let name = (noArgMsgSend(devInstance, nameSel) as? String) ?? "iOS Device"
        let isEnabled = boolMsgSend(devInstance, isEnabledSel)
        print("[IDAM] iOS device attached: '\(name)' (IDAM enabled: \(isEnabled))")
        
        // Auto-enable if enabled in settings
        if appState?.autoIDAMEnabled != false && !isEnabled {
            enableIDAM(for: devInstance, name: name)
        } else if isEnabled {
            // Already enabled, switch input if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AudioEngine.shared.setInputToIPad()
            }
        }
    }
    
    private func deviceDisconnected(devPtr: AMDeviceRef) {
        if let devInstance = connectedDevices.removeValue(forKey: devPtr) {
            let name = (noArgMsgSend?(devInstance, nameSel) as? String) ?? "iOS Device"
            print("[IDAM] iOS device detached: '\(name)'")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioEngine.shared.updateState()
        }
    }
    
    private func enableIDAM(for devInstance: AnyObject, name: String) {
        guard let noArgMsgSend = noArgMsgSend,
              let boolMsgSend = boolMsgSend else { return }
        
        print("[IDAM] Natively activating IDAM for '\(name)' (no Audio MIDI Setup window needed)...")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Validate device session and connect to CoreAudio ASAP service
            let valid = boolMsgSend(devInstance, self.validateSel)
            if valid {
                // Step 2: Activate audio interface
                _ = noArgMsgSend(devInstance, self.connectSel)
                print("[IDAM] Successfully sent IDAM activation to '\(name)'!")
                
                // Step 3: Switch default input to iPad once CoreAudio registers it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    AudioEngine.shared.setInputToIPad()
                }
            } else {
                print("[IDAM] validateDevice failed for '\(name)'.")
            }
        }
    }
    
    @objc private func handleManualTrigger() {
        print("[IDAM] Manual IDAM trigger invoked.")
        guard appState?.autoIDAMEnabled != false else {
            print("[IDAM] IDAM auto-activation disabled by user.")
            return
        }
        
        guard !connectedDevices.isEmpty else {
            print("[IDAM] No iOS devices currently registered in NativeIDAMAutomator.")
            return
        }
        
        for (_, devInstance) in connectedDevices {
            let name = (noArgMsgSend?(devInstance, nameSel) as? String) ?? "iOS Device"
            let isEnabled = boolMsgSend?(devInstance, isEnabledSel) ?? false
            if !isEnabled {
                enableIDAM(for: devInstance, name: name)
            } else {
                print("[IDAM] '\(name)' is already enabled. Switching input...")
                AudioEngine.shared.setInputToIPad()
            }
        }
    }
    
    var hasConnectedDevices: Bool {
        return !connectedDevices.isEmpty
    }
}
