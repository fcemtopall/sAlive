import Foundation
import IOKit.ps

struct BatteryInfo {
    var onBattery: Bool
    var percent: Int?
}

private var batteryChangeHandler: (() -> Void)?

enum Battery {
    static func current() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryInfo(onBattery: false, percent: nil)
        }
        let source = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        var info = BatteryInfo(onBattery: source == kIOPMBatteryPowerKey, percent: nil)

        if let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for powerSource in list {
                guard
                    let description = IOPSGetPowerSourceDescription(snapshot, powerSource)?
                        .takeUnretainedValue() as? [String: Any],
                    let current = description[kIOPSCurrentCapacityKey] as? Int,
                    let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
                else { continue }
                info.percent = current * 100 / max
                break
            }
        }
        return info
    }

    /// Calls `handler` on the main run loop whenever power source info changes.
    static func observe(_ handler: @escaping () -> Void) {
        batteryChangeHandler = handler
        guard let source = IOPSNotificationCreateRunLoopSource({ _ in batteryChangeHandler?() }, nil)?
            .takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
}
