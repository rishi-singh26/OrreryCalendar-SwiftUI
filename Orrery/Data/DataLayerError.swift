//
//  DataLayerError.swift
//  Orrery
//

import Foundation

struct DataLayerError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
