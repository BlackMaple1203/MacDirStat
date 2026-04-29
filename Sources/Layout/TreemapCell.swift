import SwiftUI

public struct TreemapCell: Identifiable {
    public let id: UUID = UUID()
    public let node: FSNode
    public let rect: CGRect
    public let color: Color
    public let depth: Int
}
