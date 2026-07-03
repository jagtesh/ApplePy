// ApplePy – SPM Command Plugin for bundling
// Renames the built .dylib/.so to the correct CPython extension naming convention
// and copies it to a dist/ directory.
//
// Usage: swift package plugin applepy-bundle --target MyExtension

import PackagePlugin
import Foundation

@main
struct ApplePyBundlePlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // Parse arguments
        var targetName: String?
        var moduleName: String?
        var argIterator = arguments.makeIterator()
        while let arg = argIterator.next() {
            switch arg {
            case "--target":
                targetName = argIterator.next()
            case "--module-name":
                moduleName = argIterator.next()
            default:
                break
            }
        }

        guard let targetName = targetName else {
            Diagnostics.error("Usage: swift package plugin applepy-bundle --target <TargetName> [--module-name <name>]")
            return
        }

        let modName = moduleName ?? targetName.lowercased()

        // Detect Python tag and platform
        let pythonExecutable = try detectPythonExecutable()
        let pythonTag = try runShell(pythonExecutable, "-c", "import sys; print(f'cpython-{sys.version_info.major}{sys.version_info.minor}')")
        let platform = try detectPlatform()

        let soName = "\(modName).\(pythonTag)-\(platform).so"

        // Find the build artifact
        let buildDir = context.pluginWorkDirectoryURL.deletingLastPathComponent().deletingLastPathComponent()
        let debugDir = buildDir.appending(path: "debug")

        let possibleNames = [
            "lib\(targetName).dylib",
            "lib\(targetName).so",
            "\(targetName).dylib",
            "\(targetName).so",
        ]

        var sourceFile: URL?
        for name in possibleNames {
            let candidate = debugDir.appending(path: name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                sourceFile = candidate
                break
            }
        }

        guard let sourceFile = sourceFile else {
            Diagnostics.error("Could not find built library for target '\(targetName)' in \(debugDir.path)")
            Diagnostics.remark("Looked for: \(possibleNames.joined(separator: ", "))")
            return
        }

        // Create dist directory
        let distDir = context.pluginWorkDirectoryURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appending(path: "dist")
        try FileManager.default.createDirectory(at: distDir, withIntermediateDirectories: true)

        // Copy and rename
        let destFile = distDir.appending(path: soName)
        if FileManager.default.fileExists(atPath: destFile.path) {
            try FileManager.default.removeItem(at: destFile)
        }
        try FileManager.default.copyItem(at: sourceFile, to: destFile)

        Diagnostics.remark("✅ Bundled: \(destFile.path)")
        Diagnostics.remark("Import with: \(pythonExecutable) -c 'import \(modName)'")
    }

    /// Locate a usable Python 3 interpreter on PATH, trying the generic
    /// `python3` first and falling back to specific minor versions in
    /// descending order (`python3.13`, `python3.12`, ..., `python3.9`).
    /// This avoids hardcoding a single Python version that may not be
    /// installed on the host machine.
    private func detectPythonExecutable() throws -> String {
        let candidates = ["python3", "python3.13", "python3.12", "python3.11", "python3.10", "python3.9"]
        for candidate in candidates {
            if !(try runShell("which", candidate)).isEmpty {
                return candidate
            }
        }
        throw PluginError.pythonNotFound
    }

    private func runShell(_ args: String...) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = Array(args)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func detectPlatform() throws -> String {
        #if os(macOS)
        return "darwin"
        #elseif os(Linux)
        let arch = try runShell("uname", "-m")
        return "linux-\(arch)"
        #else
        return "unknown"
        #endif
    }
}

enum PluginError: Error, CustomStringConvertible {
    case pythonNotFound

    var description: String {
        switch self {
        case .pythonNotFound:
            return "Could not find a Python 3 interpreter on PATH (tried python3, python3.13, python3.12, python3.11, python3.10, python3.9)"
        }
    }
}
