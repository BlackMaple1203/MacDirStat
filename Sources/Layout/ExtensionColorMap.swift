import SwiftUI

public struct ExtensionColorMap: Equatable {
    private var map: [String: Color] = [:]

    public init(root: FSNode) {
        var extensions = Set<String>()
        collect(node: root, into: &extensions)
        for ext in extensions {
            let hash = ext.utf8.reduce(UInt32(5381)) { ($0 &<< 5) &+ $0 &+ UInt32($1) }
            let hue = Double(hash % 360) / 360.0
            map[ext] = Color(hue: hue, saturation: 0.65, brightness: 0.82)
        }
    }

    public func color(for fileExtension: String) -> Color {
        map[fileExtension] ?? Color(white: 0.55)
    }

    private func collect(node: FSNode, into set: inout Set<String>) {
        if !node.isDirectory && !node.fileExtension.isEmpty {
            set.insert(node.fileExtension)
        }
        for child in node.children { collect(node: child, into: &set) }
    }
}
