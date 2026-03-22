// ApplePy – SPM Build Tool Plugin
// Auto-detects Python installation and provides compiler/linker flags.
// Usage in Package.swift: .plugin(name: "ApplePyBuild") in a target's plugins array.

import PackagePlugin

@main
struct ApplePyBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // The build tool plugin runs at build time and can provide prebuild commands.
        // For ApplePy, the Python detection is handled via pkg-config in the system library
        // target, so this plugin focuses on post-build renaming.
        return []
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ApplePyBuildPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        return []
    }
}
#endif
