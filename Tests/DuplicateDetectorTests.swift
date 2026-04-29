import XCTest
@testable import MacDirStat

final class DuplicateDetectorTests: XCTestCase {

    func test_detects_identical_files() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let data = Data(repeating: 42, count: 8192)
        let f1 = tmp.appendingPathComponent("copy1.bin")
        let f2 = tmp.appendingPathComponent("copy2.bin")
        let f3 = tmp.appendingPathComponent("unique.bin")
        try data.write(to: f1)
        try data.write(to: f2)
        try Data(repeating: 99, count: 8192).write(to: f3)

        let root = FSNode(url: tmp, name: tmp.lastPathComponent, isDirectory: true, size: 0, fileExtension: "", parent: nil)
        for url in [f1, f2, f3] {
            let name = url.lastPathComponent
            let ext = url.pathExtension
            let child = FSNode(url: url, name: name, isDirectory: false, size: Int64(data.count), fileExtension: ext, parent: root)
            root.children.append(child)
            root.size += child.size
        }

        let detector = DuplicateDetector()
        await detector.detect(in: root)

        let copy1 = root.children.first { $0.name == "copy1.bin" }!
        let copy2 = root.children.first { $0.name == "copy2.bin" }!
        let unique = root.children.first { $0.name == "unique.bin" }!

        XCTAssertNotNil(copy1.duplicateGroupID)
        XCTAssertNotNil(copy2.duplicateGroupID)
        XCTAssertEqual(copy1.duplicateGroupID, copy2.duplicateGroupID)
        XCTAssertNil(unique.duplicateGroupID, "unique file must not be grouped")
    }

    func test_small_files_below_threshold_are_skipped() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let tinyData = Data(repeating: 1, count: 100) // below 4KB threshold
        let f1 = tmp.appendingPathComponent("tiny1.txt")
        let f2 = tmp.appendingPathComponent("tiny2.txt")
        try tinyData.write(to: f1)
        try tinyData.write(to: f2)

        let root = FSNode(url: tmp, name: "root", isDirectory: true, size: 0, fileExtension: "", parent: nil)
        for url in [f1, f2] {
            let child = FSNode(url: url, name: url.lastPathComponent, isDirectory: false, size: Int64(tinyData.count), fileExtension: "txt", parent: root)
            root.children.append(child)
        }

        let detector = DuplicateDetector()
        await detector.detect(in: root)

        XCTAssertNil(root.children[0].duplicateGroupID, "files below threshold should not be grouped")
        XCTAssertNil(root.children[1].duplicateGroupID)
    }
}
