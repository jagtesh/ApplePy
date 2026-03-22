// ApplyPy – SPM Build Tool Plugin
// Auto-detects Python installation and provides compiler/linker flags.
// Usage in Package.swift: .plugin(name: "ApplyPyBuild") in a target's plugins array.

import PackagePlugin

@main
struct ApplyPyBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // The build tool plugin runs at build time and can provide prebuild commands.
        // For ApplyPy, the Python detection is handled via pkg-config in the system library
        // target, so this plugin focuses on post-build renaming.
        return []
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ApplyPyBuildPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        return []
    }
}
#endif
