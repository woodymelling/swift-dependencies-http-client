//
//  HttpClient.swift
//  
//
//  Created by Woodrow Melling on 8/8/23.
//

import Foundation

#if canImport(OSLog)
import OSLog
#elseif canImport(AndroidLogging)
import AndroidLogging
#endif

import Dependencies
import DependenciesMacros
import HTTPTypes

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A lightweight HTTPClient, which provides standard HTTP requests, and deep configuration tools.
/// This is designed around the swift-dependencies library, and we use .dependency to configure the client.
@DependencyClient
public struct HTTPClient: Sendable {
    public var run: @Sendable (_ request: HTTPRequest, Data?) async throws -> Data?
}

extension DependencyValues {
    public var httpClient: HTTPClient {
        get { self[HTTPClient.self] }
        set { self[HTTPClient.self] = newValue }
    }
}

extension HTTPClient: DependencyKey {
    public static let liveValue: HTTPClient = HTTPClient { request, body in
        @Dependency(\.requestInterceptors) var requestInterceptors
        @Dependency(\.responseInterceptors) var responseInterceptors
        @Dependency(\.errorInterceptors) var errorInterceptors

        @Sendable func _run(_ request: HTTPRequest, remainingRetries: Int) async throws -> Data? {
            var request = request
            var body = body

            for interceptor in requestInterceptors {
                try await interceptor.run(&request, &body)
            }

            // Use a super lightweight wrapper around URLSession.shared.run,
            // This allows us to override this when testing with a simple closure matching the shape of URLSession.run
            @Dependency(\.dataForURL) var dataForURL
            var (data, httpResponse) = try await dataForURL(request, body)

            for interceptor in responseInterceptors {
                try await interceptor.run(request, &httpResponse, &data)
            }

            if httpResponse.status.kind != .successful {
                @Dependency(\.errorInterceptors) var errorInterceptors
                if remainingRetries > 0 {
                    for interceptor in errorInterceptors {
                        if let result = try await interceptor.interceptor(
                            request,
                            httpResponse.status,
                            httpResponse.headerFields,
                            data,
                            { request in try await _run(request, remainingRetries: remainingRetries - 1) }
                        ) {
                            return result
                        }
                    }
                }
                throw HTTPError.httpError(httpResponse.status, data, httpResponse.headerFields)
            }

            return data
        }

        let data = try await _run(request, remainingRetries: errorInterceptors.count)

        // If we get a non-response back from the network, URLSession returns a non-nil, but empty Data() value.
        // This line handles that, and returns nil, which is a better representation of the response data
        if let data, !data.isEmpty {
            return data
        } else {
            return nil
        }

    }
}

import HTTPTypesFoundation

/// RunHTTPRequest is the low-level hook that maps a fully-intercepted HTTPRequest to a raw network response.
/// Override `DependencyValues.dataForURL` in tests to inspect the request (including headers set by
/// request interceptors) or to return canned responses without hitting the network.
public typealias RunHTTPRequest = @Sendable (_ request: HTTPRequest, _ data: Data?) async throws -> (Data, HTTPResponse)
internal enum RunHTTPRequestDependencyKey: DependencyKey {

    static let liveValue: RunHTTPRequest = { request, data in
        if let data {
            return try await URLSession.shared.upload(for: request, from: data)
        } else {
            return try await URLSession.shared.data(for: request)
        }
    }
}

extension DependencyValues {
    public var dataForURL: RunHTTPRequest {
        get { self[RunHTTPRequestDependencyKey.self] }
        set { self[RunHTTPRequestDependencyKey.self] = newValue }
    }
}

extension HTTPClient {

    func buildHTTPRequest(
        url: URL,
        method: HTTPRequest.Method,
        queryItems: [URLQueryItem]
    ) throws -> HTTPRequest {
        var url = url
        addQueryItems(queryItems, to: &url)

        var request = HTTPRequest(url: url)
        request.method = method

        @Dependency(\.requestHeaders) var headers

        request.headerFields = headers
        return request
    }

}

// MARK: HTTPMethods public interface
extension HTTPClient {
    /// Make an http GET request and decode it to an output type
    public func get<Output: Decodable>(
        _ url: URL,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output {
        let request = try buildHTTPRequest(url: url, method: .get, queryItems: queryItems)

        let data = try await self.run(request, nil)

        // HTTPGet should always have a data response. (Right?)
        guard let data
        else { throw HTTPError.expectedDataResponse }

        // If we specifically request a `Data` type, we don't need to do any decoding
        if let data = data as? Output { return data }

        @Dependency(\.jsonDecoder) var jsonDecoder
        return try jsonDecoder.decode(Output.self, from: data)
    }

    public func post<Output: Decodable>(
        _ url: URL,
        body: Data,
        decodingTo: Output.Type = Output.self
    ) async throws -> Output {
        @Dependency(\.jsonDecoder) var jsonDecoder

        let request = try buildHTTPRequest(url: url, method: .post, queryItems: [])
        let responseData = try await self.run(request, body)

        return try jsonDecoder.decode(Output.self, from: responseData ?? Data())
    }

    public func post<Input: Encodable, Output: Decodable>(
        _ url: URL,
        data: Input? = CodableVoid?.none,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output {
        @Dependency(\.jsonDecoder) var jsonDecoder
        @Dependency(\.jsonEncoder) var jsonEncoder

        let request = try buildHTTPRequest(url: url, method: .post, queryItems: queryItems)

        let body = try data.map { try jsonEncoder.encode($0) }

        let responseData = try await self.run(request, body)

        return try jsonDecoder.decode(Output.self, from: responseData ?? CodableVoid.data)
    }

    public func put<Input, Output>(
        _ url: URL,
        data: Input?,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output where Input : Encodable, Output : Decodable {
        @Dependency(\.jsonDecoder) var jsonDecoder
        @Dependency(\.jsonEncoder) var jsonEncoder

        let request = try buildHTTPRequest(url: url, method: .put, queryItems: queryItems)
        let body = try data.map { try jsonEncoder.encode($0) }

        let responseData = try await self.run(request, body)

        return try jsonDecoder.decode(Output.self, from: responseData ?? CodableVoid.data)
    }

    public func delete(
        _ url: URL,
        queryItems: [URLQueryItem] = []
    ) async throws {
        let request = try buildHTTPRequest(url: url, method: .delete, queryItems: queryItems)

        _ = try await run(request, nil)
    }
}



// MARK: Path Based API
// The base url is dependency injected in these endpoints
extension HTTPClient {
    public func get<Output: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output {
        try await get(URL(path: path), queryItems: queryItems)
    }

    public func post<Input: Encodable, Output: Decodable>(
        _ path: String,
        data: Input? = CodableVoid?.none,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output {
        try await post(URL(path: path), data: data, queryItems: queryItems)
    }


    public func put<Input, Output>(
        _ path: String,
        data: Input?,
        queryItems: [URLQueryItem] = [],
        decodingTo: Output.Type = Output.self
    ) async throws -> Output where Input : Encodable, Output : Decodable {
        try await put(URL(path: path), data: data, queryItems: queryItems, decodingTo: Output.self)
    }


    public func delete(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws {
        try await delete(URL(path: path), queryItems: queryItems)
    }
}


// These are overloads for when the Response type to POST and PUT are going to be empty.
extension HTTPClient {
    public func put<Input: Encodable>(
        url: URL,
        data: Input? = CodableVoid?.none,
        queryItems: [URLQueryItem] = []
    ) async throws {
        let _: CodableVoid = try await put(url, data: data, queryItems: [])
    }

    public func put<Input: Encodable>(
        _ path: String,
        data: Input? = CodableVoid?.none,
        queryItems: [URLQueryItem] = []
    ) async throws {
        let _: CodableVoid = try await put(path, data: data, queryItems: [])
    }

    public func post<Input: Encodable>(
        _ path: String,
        data: Input = CodableVoid(),
        queryItems: [URLQueryItem] = []
    ) async throws {
        let _: CodableVoid = try await post(path, data: data, queryItems: [])
        return
    }

    public func post<Input: Encodable>(
        _ url: URL,
        data: Input = CodableVoid(),
        queryItems: [URLQueryItem] = []
    ) async throws {
        let _: CodableVoid = try await post(url, data: data, queryItems: [])
        return
    }
}


