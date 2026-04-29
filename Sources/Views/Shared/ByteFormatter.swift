import Foundation

public enum ByteFormatter {
    public static func string(from bytes: Int64) -> String {
        let kb: Int64 = 1024
        let mb = kb * 1024
        let gb = mb * 1024
        let tb = gb * 1024
        switch bytes {
        case tb...: return String(format: "%.1f TB", Double(bytes) / Double(tb))
        case gb...: return String(format: "%.1f GB", Double(bytes) / Double(gb))
        case mb...: return String(format: "%.1f MB", Double(bytes) / Double(mb))
        case kb...: return String(format: "%.1f KB", Double(bytes) / Double(kb))
        default:    return "\(bytes) B"
        }
    }
}
