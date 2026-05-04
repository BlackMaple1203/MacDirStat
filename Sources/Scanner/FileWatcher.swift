import Foundation
import CoreServices

/// Wraps FSEventStreamCreate with a 1.5 s coalescing window.
/// The kernel batches all events within that window into one callback,
/// so bulk operations (npm install, Xcode builds, git checkout) arrive
/// as a single notification instead of thousands.
final class FileWatcher {

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "MacDirStat.filewatcher", qos: .utility)

    func start(watching url: URL, onChanges: @escaping ([String]) -> Void) {
        stop()
        let pathsToWatch = [url.path] as CFArray
        let box = Unmanaged.passRetained(CallbackBox(onChanges))

        var ctx = FSEventStreamContext(
            version: 0,
            info: box.toOpaque(),
            retain: nil,
            release: { ptr in ptr.map { Unmanaged<CallbackBox>.fromOpaque($0).release() } },
            copyDescription: nil
        )

        stream = FSEventStreamCreate(
            nil,
            { _, info, count, rawPaths, _, _ in
                guard let info else { return }
                let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()
                let arr = unsafeBitCast(rawPaths, to: NSArray.self)
                let paths = (0..<count).compactMap { arr[$0] as? String }
                box.value(paths)
            },
            &ctx,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.5,    // coalescing window in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )

        guard let s = stream else { return }
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
    }

    func stop() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    deinit { stop() }
}

private final class CallbackBox {
    let value: ([String]) -> Void
    init(_ v: @escaping ([String]) -> Void) { value = v }
}
