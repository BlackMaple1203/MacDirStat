import XCTest
import SwiftUI
@testable import MacDirStat

final class TreemapLayoutTests: XCTestCase {

    func test_extension_color_map_returns_consistent_color() {
        let root = makeTree([("a.pdf", 100), ("b.pdf", 200), ("c.mp4", 300)])
        let map = ExtensionColorMap(root: root)
        let c1 = map.color(for: "pdf")
        let c2 = map.color(for: "pdf")
        XCTAssertEqual(c1, c2, "same extension must return same color")
    }

    func test_extension_color_map_different_extensions_get_different_colors() {
        let root = makeTree([("a.pdf", 100), ("b.mp4", 200)])
        let map = ExtensionColorMap(root: root)
        XCTAssertNotEqual(map.color(for: "pdf"), map.color(for: "mp4"))
    }

    func test_byte_formatter_kb() {
        XCTAssertEqual(ByteFormatter.string(from: 1024), "1.0 KB")
    }

    func test_byte_formatter_mb() {
        XCTAssertEqual(ByteFormatter.string(from: 1024 * 1024), "1.0 MB")
    }

    func test_byte_formatter_gb() {
        XCTAssertEqual(ByteFormatter.string(from: 1024 * 1024 * 1024), "1.0 GB")
    }

    func test_byte_formatter_bytes() {
        XCTAssertEqual(ByteFormatter.string(from: 500), "500 B")
    }

    // MARK: - Helpers

    func makeTree(_ files: [(String, Int64)]) -> FSNode {
        let root = FSNode(url: URL(fileURLWithPath: "/"), name: "/", isDirectory: true, size: 0, fileExtension: "", parent: nil)
        for (name, size) in files {
            let ext = (name as NSString).pathExtension.lowercased()
            let child = FSNode(url: URL(fileURLWithPath: "/\(name)"), name: name, isDirectory: false, size: size, fileExtension: ext, parent: root)
            root.children.append(child)
            root.size += size
        }
        return root
    }
}
