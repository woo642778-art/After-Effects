import Foundation
import VertexAI

#if canImport(Darwin)
import Darwin
#endif

public enum CoreMLCapabilityProfiler {
    public static func current() -> AICapabilityProfile {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        // Never advertise the entire physical memory pool to inference. The
        // scheduler uses this as a bounded working-set budget, not free RAM.
        let budget = max(UInt64(512_000_000), physicalMemory / 3)

        #if os(iOS)
        let eligible = HardwareClassClassifier.supportsMaxQuality(machineIdentifier: machineIdentifier())
        #if targetEnvironment(simulator)
        let neuralEngine = false
        #else
        let neuralEngine = true
        #endif
        #else
        #if arch(arm64)
        let eligible = true
        #else
        let eligible = false
        #endif
        let neuralEngine = eligible
        #endif

        #if canImport(Darwin)
        let thermal = ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical
        #else
        let thermal = false
        #endif

        return AICapabilityProfile(
            supportsMaxQualityByHardwareClass: eligible,
            memoryBudgetBytes: budget,
            thermalRestricted: thermal,
            neuralEngineAvailable: neuralEngine
        )
    }

    private static func machineIdentifier() -> String {
        #if canImport(Darwin)
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let bytes = mirror.children.compactMap { element -> UInt8? in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return UInt8(bitPattern: value)
        }
        return String(decoding: bytes, as: UTF8.self)
        #else
        return "unknown"
        #endif
    }
}

public enum HardwareClassClassifier {
    /// Conservative allow-list for the user's approved Max Quality floor:
    /// A17 Pro-class iPhones and M1-class-or-newer iPads.
    public static func supportsMaxQuality(machineIdentifier: String) -> Bool {
        if let (family, major, minor) = parse(machineIdentifier) {
            switch family {
            case "iPhone":
                // iPhone16,1/2 are A17 Pro; later iPhone generations meet or exceed it.
                return major >= 16
            case "iPad":
                if major > 16 { return true }
                if major == 16 { return true } // A17 Pro mini / M4 generation
                if major == 14 { return [3, 4, 5, 6, 8, 9, 10, 11].contains(minor) }
                if major == 13 { return (4...11).contains(minor) || (16...17).contains(minor) }
                return false
            default:
                return false
            }
        }
        return false
    }

    private static func parse(_ value: String) -> (String, Int, Int)? {
        guard let comma = value.firstIndex(of: ",") else { return nil }
        let leading = String(value[..<comma])
        let minorText = String(value[value.index(after: comma)...])
        let family = leading.prefix { !$0.isNumber }
        let majorText = leading.dropFirst(family.count)
        guard let major = Int(majorText), let minor = Int(minorText) else { return nil }
        return (String(family), major, minor)
    }
}
