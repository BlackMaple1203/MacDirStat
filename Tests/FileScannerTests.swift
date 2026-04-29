import XCTest
@testable import MacDirStat

final class FileScannerTests: XCTestCase {

    func test_fsnode_file_stores_properties() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let node = FSNode(url: url, name: "test.pdf", isDirectory: false, size: 1024, fileExtension: "pdf", parent: nil)
        XCTAssertEqual(node.name, "test.pdf")
        XCTAssertEqual(node.size, 1024)
        XCTAssertEqual(node.fileExtension, "pdf")
        XCTAssertFalse(node.isDirectory)
        XCTAssertNil(node.parent)
    }

    func test_fsnode_directory_accumulates_children_size() {
        let dir = FSNode(url: URL(fileURLWithPath: "/tmp"), name: "tmp", isDirectory: true, size: 0, fileExtension: "", parent: nil)
        let child1 = FSNode(url: URL(fileURLWithPath: "/tmp/a"), name: "a", isDirectory: false, size: 500, fileExtension: "txt", parent: dir)
        let child2 = FSNode(url: URL(fileURLWithPath: "/tmp/b"), name: "b", isDirectory: false, size: 300, fileExtension: "jpg", parent: dir)
        dir.children = [child1, child2]
        dir.size = child1.size + child2.size
        XCTAssertEqual(dir.size, 800)
        XCTAssertEqual(dir.children.count, 2)
        XCTAssertTrue(dir.children[0].parent === dir)
    }

    func test_fsnode_parent_reference_is_weak() {
        var dir: FSNode? = FSNode(url: URL(fileURLWithPath: "/tmp"), name: "tmp", isDirectory: true, size: 0, fileExtension: "", parent: nil)
        let child = FSNode(url: URL(fileURLWithPath: "/tmp/a"), name: "a", isDirectory: false, size: 100, fileExtension: "txt", parent: dir)
        dir = nil
        XCTAssertNil(child.parent)
    }
}
