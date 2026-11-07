import Foundation
import os

/// An append-only log in the App Group container.
///
/// `devicectl` cannot launch or attach to a Messages extension, so `print`
/// from one goes nowhere reachable. This is how the extension reports what
/// happened: `scripts/device-library.sh pull` brings it back.
public enum Diagnostics {
    private static let lock = OSAllocatedUnfairLock(initialState: ())

    /// Deliberately outside the stickers folder, so the store never sees it.
    public static var fileURL: URL? {
        let fileManager = FileManager.default
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Identifiers.appGroup)
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        let directory = base.appendingPathComponent("Library/Caches", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diagnostics.log")
    }

    public static func log(_ message: @autoclosure () -> String, process: String = ProcessInfo.processInfo.processName) {
        guard let url = fileURL else { return }
        let line = "\(Date().formatted(date: .omitted, time: .standard)) [\(process)] \(message())\n"
        lock.withLock {
            guard let handle = try? FileHandle(forWritingTo: url) else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
                return
            }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }

    /// Everything an error can tell us, including the underlying `NSError`
    /// that a `localizedDescription` alone leaves out.
    public static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = ["\(type(of: error)) \(error)"]
        parts.append("domain=\(nsError.domain) code=\(nsError.code)")
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying=\(underlying.domain)/\(underlying.code) \(underlying.localizedDescription)")
        }
        if let path = nsError.userInfo[NSFilePathErrorKey] as? String {
            parts.append("path=\(path)")
        }
        return parts.joined(separator: " | ")
    }
}
