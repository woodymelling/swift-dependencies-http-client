//
//  JSONEncoderDependencyKey.swift
//  swift-dependencies-http
//
//  Created by Woodrow Melling on 10/8/25.
//


//
//  HTTPClient+JSONCoding.swift
//  
//
//  Created by Woodrow Melling on 8/14/23.
//

import Foundation
import Dependencies

internal enum JSONEncoderDependencyKey: DependencyKey {
    static let liveValue = JSONEncoder()
    static let testValue = JSONEncoder()
}

internal enum JSONDecoderDependencyKey: DependencyKey {
    static let liveValue = JSONDecoder()
    static let testValue = JSONDecoder()
}

public extension DependencyValues {
    var jsonEncoder: JSONEncoder {
        get { self[JSONEncoderDependencyKey.self] }
        set { self[JSONEncoderDependencyKey.self] = newValue }
    }

    var jsonDecoder: JSONDecoder {
        get { self[JSONDecoderDependencyKey.self] }
        set { self[JSONDecoderDependencyKey.self] = newValue }
    }
}


