//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/18/23.
//

import Foundation
import Dependencies
import HTTPTypes

public struct RequestInterceptor: Sendable {
    public var run: @Sendable (inout HTTPRequest, inout Data?) async throws -> Void

    public init(run: @Sendable @escaping (inout HTTPRequest, inout Data?) async throws -> Void) {
        self.run = run
    }
}

extension RequestInterceptor: DependencyKey {
    public static let liveValue: [RequestInterceptor] = [
        RequestInterceptor { request, body in
            let request = request

            var bodyLog: String?

            if let prettyBody = body?.prettyJSONString {
                bodyLog = """
                body:
                \(prettyBody)
                """
            }

            Logger.httpRequests.log(
                """
                   \(request.method) \(request.url?.absoluteString ?? "")
                   \(bodyLog ?? "")
                """
            )
        }
    ]
}

extension DependencyValues {
    public var requestInterceptors: [RequestInterceptor] {
        get { self[RequestInterceptor.self] }
        set { self[RequestInterceptor.self] = newValue }
    }
}

public struct ResponseInterceptor: Sendable {
    public var run: @Sendable (_ request: HTTPRequest, _ response: inout HTTPResponse, _ responseData: inout Data) async throws -> Void

    public init(run: @Sendable @escaping (_ request: HTTPRequest, _ response: inout HTTPResponse, _ data: inout Data) -> Void) {
        self.run = run
    }
}

extension ResponseInterceptor: DependencyKey {
    public static let liveValue: [ResponseInterceptor] = [
        ResponseInterceptor { request, response, responseData in
            let response = response
            let responseData = responseData

            Logger.httpResponses.log(
            """
            response: \(response.status)
            for: \(request.method) \(request.url?.absoluteString ?? "")
            body: \(responseData.prettyJSONString)
            """
            )
        }
    ]
}

import OSLog
extension Logger {
    /// Logs  information
    static let httpRequests = Logger(subsystem: "Networking", category: "HTTPRequests")
    static let httpResponses = Logger(subsystem: "Networking", category: "HTTPResponses")
}

extension DependencyValues {
    public var responseInterceptors: [ResponseInterceptor] {
        get { self[ResponseInterceptor.self] }
        set { self[ResponseInterceptor.self] = newValue }
    }
}

public struct ErrorInterceptor: Sendable {

    var maxRetries: Int = 1
    var interceptor: Interceptor

    public typealias Interceptor = @Sendable (_ failedRequest: HTTPRequest, _ failureCode: HTTPResponse.Status, _ failureBody: Data?, _ retry: @escaping @Sendable (HTTPRequest) async throws -> Data?) async throws -> Data?

    public init(
        maxRetries: Int,
        interceptor: @escaping Interceptor
    ) {
        self.maxRetries = maxRetries
        self.interceptor = interceptor
    }
}

extension ErrorInterceptor: DependencyKey {
    public static let liveValue: ErrorInterceptor? = nil
}

extension DependencyValues {
    public var errorInterceptor: ErrorInterceptor? {
        get { self[ErrorInterceptor.self] }
        set { self[ErrorInterceptor.self] = newValue }
    }
}
