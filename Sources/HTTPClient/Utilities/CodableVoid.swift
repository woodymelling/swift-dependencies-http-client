//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/18/23.
//

import Foundation

/// A Void value that conforms to Codable.
/// This shouldn't every really be interacted with outside of this library, and eventially may not be neccesary, but this is mostly to satisfy the type system, and should never store any data or have any state
/// It can only ever be one value.
/// Anything should encode into this type, and nothing should decode from it.
public struct CodableVoid: Codable {
    public init() {}

    public static var data: Data {
        try! JSONEncoder().encode(CodableVoid())
    }
}
