//
//  MacroError.swift
//  MarcolasPattern
//
//  Created by Marcus Badiale on 16/04/26.
//

import Foundation

enum MacroError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text): return text
        }
    }
}
