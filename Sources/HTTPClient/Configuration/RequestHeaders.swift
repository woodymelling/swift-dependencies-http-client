//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/12/23.
//

import Foundation
import Dependencies
import HTTPTypes

struct RequestHeadersDependencyKey: DependencyKey {
    static let liveValue: HTTPFields = [:]
    static let testValue: HTTPFields = [:]
}

extension DependencyValues {
    public var requestHeaders: HTTPFields {
        get { self[RequestHeadersDependencyKey.self] }
        set { self[RequestHeadersDependencyKey.self] = newValue }
    }
}
