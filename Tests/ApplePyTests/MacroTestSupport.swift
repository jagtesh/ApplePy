// ApplePy – Macro test support
//
// `SwiftSyntaxMacrosTestSupport.assertMacroExpansion` reports failures via
// `XCTFail`, which is silently swallowed when called from a Swift Testing
// `@Test` function (no XCTestCase is active), making macro-expansion
// assertions pass even when the expected/actual source mismatches.
//
// This helper uses the framework-agnostic `SwiftSyntaxMacrosGenericTestSupport`
// API and reports failures through Swift Testing's `Issue.record`, so
// mismatches actually fail the test.

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

func assertMacroExpansion(
    _ originalSource: String,
    expandedSource expectedExpandedSource: String,
    diagnostics: [DiagnosticSpec] = [],
    macros: [String: Macro.Type],
    testModuleName: String = "TestModule",
    testFileName: String = "test.swift",
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    let specs = macros.mapValues { MacroSpec(type: $0) }
    SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
        originalSource,
        expandedSource: expectedExpandedSource,
        diagnostics: diagnostics,
        macroSpecs: specs,
        testModuleName: testModuleName,
        testFileName: testFileName,
        failureHandler: { failure in
            Issue.record(
                Comment(rawValue: failure.message),
                sourceLocation: sourceLocation
            )
        }
    )
}
