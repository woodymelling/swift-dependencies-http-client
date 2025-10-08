//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/18/23.
//

import Foundation
import Dependencies
import HTTPTypes

public struct HTTPClientConfiguration: Sendable {
    public var hostURL: @Sendable () -> String?
    public var requestHeaders: HTTPFields
    public var requestInterceptors: [RequestInterceptor]
    public var responseInterceptors: [ResponseInterceptor]
    public var errorInterceptor: ErrorInterceptor?
    public var jsonDecoder: JSONDecoder
    public var jsonEncoder: JSONEncoder

    public init(
        hostURL: String?,
        requestHeaders: HTTPFields,
        requestInterceptors: [RequestInterceptor],
        responseInterceptors: [ResponseInterceptor],
        errorInterceptor: ErrorInterceptor?,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder
    ) {
        self.hostURL = { hostURL }
        self.requestHeaders = requestHeaders
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.errorInterceptor = errorInterceptor
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }

    public init(
        hostURL: @Sendable @escaping () -> String?,
        requestHeaders: HTTPFields,
        requestInterceptors: [RequestInterceptor],
        responseInterceptors: [ResponseInterceptor],
        errorInterceptor: ErrorInterceptor?,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder
    ) {
        self.hostURL = hostURL
        self.requestHeaders = requestHeaders
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.errorInterceptor = errorInterceptor
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }
}

extension DependencyValues {
    public var httpConfiguration: HTTPClientConfiguration {
        get {
            return HTTPClientConfiguration(
                hostURL: self.hostURL,
                requestHeaders: self.requestHeaders,
                requestInterceptors: self.requestInterceptors,
                responseInterceptors: self.responseInterceptors,
                errorInterceptor: self.errorInterceptor,
                jsonDecoder: self.jsonDecoder,
                jsonEncoder: self.jsonEncoder
            )
        }
        set {
            self.getHostURL = newValue.hostURL
            self.requestHeaders = newValue.requestHeaders
            self.requestInterceptors = newValue.requestInterceptors
            self.responseInterceptors = newValue.responseInterceptors
            self.errorInterceptor = newValue.errorInterceptor
            self.jsonDecoder = newValue.jsonDecoder
            self.jsonEncoder = newValue.jsonEncoder
        }
    }
}

enum HostURLDependencyKey: DependencyKey {
    static let liveValue: @Sendable () -> String? = { nil }
}

extension DependencyValues {
    public var getHostURL: @Sendable () -> String? {
        get { self[HostURLDependencyKey.self] }
        set { self[HostURLDependencyKey.self] = newValue }
    }

    public var hostURL: String? {
        get { self[HostURLDependencyKey.self]() }
        set { self[HostURLDependencyKey.self] = { @Sendable in newValue }}
    }
}
