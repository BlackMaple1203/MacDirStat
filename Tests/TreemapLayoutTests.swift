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

    func test_layout_single_item_fills_rect() {
        let root = makeTree([("a.pdf", 1000)])
        let map = ExtensionColorMap(root: root)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let cells = TreemapLayout.compute(root: root, in: rect, colorMap: map)
        XCTAssertEqual(cells.count, 1)
        XCTAssertTrue(cells[0].rect.intersects(rect))
    }

    func test_layout_two_equal_items_fill_rect() {
        let root = makeTree([("a.pdf", 500), ("b.mp4", 500)])
        let map = ExtensionColorMap(root: root)
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let cells = TreemapLayout.compute(root: root, in: rect, colorMap: map)
        XCTAssertEqual(cells.count, 2)
        let totalArea = cells.reduce(0.0) { $0 + $1.rect.width * $1.rect.height }
        XCTAssertEqual(totalArea, rect.width * rect.height, accuracy: 10)
    }

    func test_layout_cells_dont_overlap() {
        let root = makeTree([("a.pdf", 300), ("b.mp4", 200), ("c.zip", 100), ("d.txt", 400)])
        let map = ExtensionColorMap(root: root)
        let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
        let cells = TreemapLayout.compute(root: root, in: rect, colorMap: map)
        for i in 0..<cells.count {
            for j in (i+1)..<cells.count {
                let intersection = cells[i].rect.intersection(cells[j].rect)
                XCTAssertTrue(intersection.isEmpty || intersection.width < 2 || intersection.height < 2,
                              "cells \(i) and \(j) overlap: \(intersection)")
            }
        }
    }

    func test_layout_cells_within_parent_rect() {
        let root = makeTree([("a.pdf", 100), ("b.mp4", 200), ("c.zip", 300)])
        let map = ExtensionColorMap(root: root)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let cells = TreemapLayout.compute(root: root, in: rect, colorMap: map)
        for cell in cells {
            XCTAssertTrue(rect.contains(cell.rect) || rect.insetBy(dx: -2, dy: -2).contains(cell.rect),
                          "cell \(cell.node.name) out of bounds: \(cell.rect)")
        }
    }

    func test_layout_empty_children_returns_no_cells() {
        let root = FSNode(url: URL(fileURLWithPath: "/"), name: "/", isDirectory: true, size: 0, fileExtension: "", parent: nil)
        let map = ExtensionColorMap(root: root)
        let cells = TreemapLayout.compute(root: root, in: CGRect(x: 0, y: 0, width: 200, height: 100), colorMap: map)
        XCTAssertTrue(cells.isEmpty)
    }

    func test_layout_larger_items_get_larger_cells() {
        let root = makeTree([("small.txt", 100), ("large.pdf", 900)])
        let map = ExtensionColorMap(root: root)
        let rect = CGRect(x: 0, y: 0, width: 400, height: 200)
        let cells = TreemapLayout.compute(root: root, in: rect, colorMap: map)
        XCTAssertEqual(cells.count, 2)
        let largeCell = cells.first { $0.node.name == "large.pdf" }!
        let smallCell = cells.first { $0.node.name == "small.txt" }!
        XCTAssertGreaterThan(largeCell.rect.width * largeCell.rect.height,
                             smallCell.rect.width * smallCell.rect.height)
    }
}
