//
//  MacroDiagnosticMessage.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 23/04/26.
//

import SwiftDiagnostics

struct MacroDiagnosticMessage: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    static func propertySkipped(name: String, reason: PropertySkipReason) -> Self {
        let msg: String
        switch reason {
        case .noTypeAnnotationOrInferrable:
            msg = "'\(name)' was skipped: add an explicit type annotation or use a recognizable initializer (e.g. let x: MyType = ...). It will not appear in the Data struct."
        case .computedWithoutType:
            msg = "'\(name)' was skipped: computed properties need an explicit type annotation (e.g. var x: Int { ... }). It will not appear in the Data struct."
        case .unsupportedPattern:
            msg = "'\(name)' uses an unsupported pattern and was skipped. It will not appear in the Data struct."
        }
        return MacroDiagnosticMessage(
            message: msg,
            diagnosticID: MessageID(domain: "MarcolasPattern", id: "skippedProperty"),
            severity: .warning
        )
    }
}
