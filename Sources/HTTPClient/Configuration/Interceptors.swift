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
            @Dependency(\.logHeaders) var logHeaders

            var parts: [String] = ["\(request.method) \(request.url?.absoluteString ?? "")"]

            if logHeaders {
                let headers = request.headerFields.map { "\($0.name): \($0.value)" }.joined(separator: "\n")
                if !headers.isEmpty { parts.append("headers:\n\(headers)") }
            }

            if let prettyBody = body?.prettyJSONString {
                parts.append("body:\n\(prettyBody)")
            }

            Logger.httpRequests.log("\(parts.joined(separator: "\n"))")
        }
    ]
}

extension DependencyValues {
    public var requestInterceptors: [RequestInterceptor] {
        get { self[RequestInterceptor.self] }
        set { self[RequestInterceptor.self] = newValue }
    }

    enum LogBodyKey: DependencyKey {
        static let liveValue = true
        static let testValue = false
    }
    public var logBody: Bool {
        get { self[LogBodyKey.self] }
        set { self[LogBodyKey.self] = newValue }
    }

    enum LogHeadersKey: DependencyKey {
        static let liveValue = false
        static let testValue = false
    }
    public var logHeaders: Bool {
        get { self[LogHeadersKey.self] }
        set { self[LogHeadersKey.self] = newValue }
    }

    enum LogEmojiKey: DependencyKey {
        static let liveValue = true
        static let testValue = false
    }
    public var logEmoji: Bool {
        get { self[LogEmojiKey.self] }
        set { self[LogEmojiKey.self] = newValue }
    }

    enum ExpectedErrorsKey: DependencyKey {
        static let liveValue: Set<ExpectedHTTPError> = []
        static let testValue: Set<ExpectedHTTPError> = []
    }
    public var expectedErrors: Set<ExpectedHTTPError> {
        get { self[ExpectedErrorsKey.self] }
        set { self[ExpectedErrorsKey.self] = newValue }
    }
}

public struct ExpectedHTTPError: Sendable, Hashable {
    public let status: HTTPResponse.Status
    public let errorCode: String?

    public init(status: HTTPResponse.Status, errorCode: String? = nil) {
        self.status = status
        self.errorCode = errorCode
    }
}

public struct ResponseInterceptor: Sendable {
    public var run: @Sendable (_ request: HTTPRequest, _ response: inout HTTPResponse, _ responseData: inout Data) async throws -> Void

    public init(run: @Sendable @escaping (_ request: HTTPRequest, _ response: inout HTTPResponse, _ data: inout Data) async throws -> Void) {
        self.run = run
    }
}

extension ResponseInterceptor: DependencyKey {
    public static let liveValue: [ResponseInterceptor] = [
        ResponseInterceptor { request, response, responseData in
            @Dependency(\.logBody) var logBody
            @Dependency(\.logHeaders) var logHeaders
            @Dependency(\.logEmoji) var logEmoji
            @Dependency(\.expectedErrors) var expectedErrors

            let isExpected = expectedErrors.contains { expected in
                guard expected.status == response.status else { return false }
                guard let errorCode = expected.errorCode else { return true }
                let decoded = try? JSONDecoder().decode(_ErrorCode.self, from: responseData)
                return decoded?.error == errorCode
            }
            let isError = response.status.kind != .successful

            let statusEmoji: String
            if logEmoji {
                statusEmoji = isExpected ? "ℹ️ " : response.status.kind.logEmoji.map { "\($0) " } ?? ""
            } else {
                statusEmoji = ""
            }

            let expectedSuffix = isExpected ? " (expected)" : ""

            var parts: [String] = [
                "\(statusEmoji)\(response.status)\(expectedSuffix) for: \(request.method) \(request.url?.absoluteString ?? "")"
            ]

            if logHeaders {
                let headers = response.headerFields.map { "\($0.name): \($0.value)" }.joined(separator: "\n")
                if !headers.isEmpty { parts.append("headers:\n\(headers)") }
            }

            if (logBody || isError), !responseData.isEmpty {
                parts.append("body: \(responseData.prettyJSONString)")
            }

            Logger.httpResponses.log("\(parts.joined(separator: "\n"))")
        }
    ]
    public static let testValue = Self.liveValue
}

#if canImport(OSLog)
import OSLog
#elseif canImport(AndroidLogging)
import AndroidLogging
#else
struct Logger: Sendable {
    init(subsystem: String, category: String) {}
    func log(_ message: String) {}
}
#endif

extension Logger {
    /// Logs  information
    static let httpRequests = Logger(subsystem: "Networking", category: "HTTPRequests")
    static let httpResponses = Logger(subsystem: "Networking", category: "HTTPResponses")
}

private struct _ErrorCode: Decodable {
    let error: String
}

private extension HTTPResponse.Status.Kind {
    var logEmoji: String? {
        switch self {
        case .successful:    return "✅"
        case .clientError:   return "⚠️"
        case .serverError:   return "🔥"
        case .redirection:   return "↩️"
        case .informational: return nil
        case .invalid:       return nil
        }
    }
}

extension DependencyValues {
    public var responseInterceptors: [ResponseInterceptor] {
        get { self[ResponseInterceptor.self] }
        set { self[ResponseInterceptor.self] = newValue }
    }
}

public struct ErrorInterceptor: Sendable {

    public var interceptor: Interceptor

    /// Return non-nil to signal the error was handled. Return nil to pass to the next interceptor.
    public typealias Interceptor = @Sendable (
        _ failedRequest: HTTPRequest,
        _ failureCode: HTTPResponse.Status,
        _ failureHeaders: HTTPFields,
        _ failureBody: Data?,
        _ retry: @escaping @Sendable (HTTPRequest) async throws -> Data?
    ) async throws -> Data?

    public init(interceptor: @escaping Interceptor) {
        self.interceptor = interceptor
    }
}

extension ErrorInterceptor: DependencyKey {
    public static let liveValue: [ErrorInterceptor] = []
    public static let testValue: [ErrorInterceptor] = []
}

extension DependencyValues {
    public var errorInterceptors: [ErrorInterceptor] {
        get { self[ErrorInterceptor.self] }
        set { self[ErrorInterceptor.self] = newValue }
    }
}
