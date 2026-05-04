import Foundation

public enum ByteFormatter {
    /// Formats bytes using the user's chosen unit style (decimal SI or binary IEC).
    public static func string(from bytes: Int64) -> String {
        let binary = UserDefaults.standard.bool(forKey: "useBinarySize")
        if binary {
            let kib: Int64 = 1_024
            let mib = kib * 1_024
            let gib = mib * 1_024
            let tib = gib * 1_024
            switch bytes {
            case tib...: return String(format: "%.1f TiB", Double(bytes) / Double(tib))
            case gib...: return String(format: "%.1f GiB", Double(bytes) / Double(gib))
            case mib...: return String(format: "%.1f MiB", Double(bytes) / Double(mib))
            case kib...: return String(format: "%.1f KiB", Double(bytes) / Double(kib))
            default:     return "\(bytes) B"
            }
        } else {
            let kb: Int64 = 1_000
            let mb = kb * 1_000
            let gb = mb * 1_000
            let tb = gb * 1_000
            switch bytes {
            case tb...: return String(format: "%.1f TB", Double(bytes) / Double(tb))
            case gb...: return String(format: "%.1f GB", Double(bytes) / Double(gb))
            case mb...: return String(format: "%.1f MB", Double(bytes) / Double(mb))
            case kb...: return String(format: "%.1f KB", Double(bytes) / Double(kb))
            default:    return "\(bytes) B"
            }
        }
    }
}
