import Foundation
import IOKit
import IOKit.usb

// MARK: - Type-safe Notification Names
extension Notification.Name {
    static let triggerIDAM = Notification.Name("TriggerIDAM")
}

// MARK: - USB Product Name Helper
func getUSBProductName(device: io_service_t) -> String {
    if let nameRef = IORegistryEntryCreateCFProperty(device, "kUSBProductString" as CFString, kCFAllocatorDefault, 0) {
        let name = nameRef.takeRetainedValue() as? String ?? ""
        if !name.isEmpty { return name }
    }
    if let nameRef2 = IORegistryEntryCreateCFProperty(device, "USB Product Name" as CFString, kCFAllocatorDefault, 0) {
        return nameRef2.takeRetainedValue() as? String ?? ""
    }
    return ""
}

class USBMonitor {
    static let shared = USBMonitor()
    
    private var notifyPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    func startMonitoring() {
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }
        
        IONotificationPortSetDispatchQueue(notifyPort, DispatchQueue.global(qos: .background))
        
        let matchingDictAdded = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        let resultAdded = IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingDictAdded,
            usbDeviceAdded,
            context,
            &addedIterator
        )
        if resultAdded == kIOReturnSuccess {
            drainIterator(iterator: addedIterator)
        }
        
        let matchingDictRemoved = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        let resultRemoved = IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchingDictRemoved,
            usbDeviceRemoved,
            context,
            &removedIterator
        )
        if resultRemoved == kIOReturnSuccess {
            drainIterator(iterator: removedIterator)
        }
    }
    
    private func drainIterator(iterator: io_iterator_t) {
        while case let dev = IOIteratorNext(iterator), dev != 0 {
            IOObjectRelease(dev)
        }
    }
}

private func usbDeviceRemoved(context: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard context != nil else { return }
    while case let dev = IOIteratorNext(iterator), dev != 0 {
        IOObjectRelease(dev)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        AudioEngine.shared.updateState()
    }
}

private func usbDeviceAdded(context: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard context != nil else { return }
    
    var foundIDAMDevice = false
    
    while case let dev = IOIteratorNext(iterator), dev != 0 {
        let name = getUSBProductName(device: dev).lowercased()
        if name.contains("ipad") || name.contains("iphone") {
            foundIDAMDevice = true
        }
        IOObjectRelease(dev)
    }
    
    if foundIDAMDevice {
        print("[USBMonitor] iPad/iPhone USB hotplug detected! Updating audio state...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioEngine.shared.updateState()
        }
    } else {
        print("[USBMonitor] USB device added, but not an iPad/iPhone.")
    }
}

extension USBMonitor {
    func isIDAMDeviceConnected() -> Bool {
        let matchingDict = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == kIOReturnSuccess else {
            return false
        }
        defer { IOObjectRelease(iterator) }
        
        while case let dev = IOIteratorNext(iterator), dev != 0 {
            let name = getUSBProductName(device: dev).lowercased()
            IOObjectRelease(dev)
            if name.contains("ipad") || name.contains("iphone") {
                // Drain remaining entries
                while case let rem = IOIteratorNext(iterator), rem != 0 {
                    IOObjectRelease(rem)
                }
                return true
            }
        }
        return false
    }
    
    // Backward compatibility alias
    func isIpadConnected() -> Bool {
        return isIDAMDeviceConnected()
    }
}
