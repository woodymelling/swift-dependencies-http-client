//
//  LiveRepositoryTests 2.swift
//  
//
//  Created by Woodrow Melling on 8/9/23.
//

import Testing
@testable import HTTPClient
import Dependencies
import HTTPTypes
import Foundation
import IssueReporting

struct FormURLEncoderTests {
    let encoder = FormURLEncoder()

    @Test func encodesSimpleStruct() throws {
        struct Params: Encodable {
            let name: String
            let count: Int
        }
        let data = try encoder.encode(Params(name: "alice", count: 3))
        #expect(String(data: data, encoding: .utf8) == "name=alice&count=3")
    }

    @Test func percentEncodesSpecialCharacters() throws {
        struct Params: Encodable { let value: String }
        let data = try encoder.encode(Params(value: "hello world&foo=bar"))
        #expect(String(data: data, encoding: .utf8) == "value=hello%20world%26foo%3Dbar")
    }

    @Test func encodesURLAsAbsoluteString() throws {
        struct Params: Encodable { let url: URL }
        let data = try encoder.encode(Params(url: URL(string: "https://example.com/callback")!))
        #expect(String(data: data, encoding: .utf8) == "url=https%3A%2F%2Fexample.com%2Fcallback")
    }

    @Test func respectsCodingKeys() throws {
        struct Params: Encodable {
            let grantType: String
            enum CodingKeys: String, CodingKey {
                case grantType = "grant_type"
            }
        }
        let data = try encoder.encode(Params(grantType: "authorization_code"))
        #expect(String(data: data, encoding: .utf8) == "grant_type=authorization_code")
    }

    @Test func encodesDefaultValues() throws {
        struct Params: Encodable {
            let code: String
            let grantType: String = "authorization_code"
            enum CodingKeys: String, CodingKey {
                case code
                case grantType = "grant_type"
            }
        }
        let data = try encoder.encode(Params(code: "abc123"))
        let result = String(data: data, encoding: .utf8)!
        #expect(result.contains("code=abc123"))
        #expect(result.contains("grant_type=authorization_code"))
    }
}

struct HTTPClientTests {

    @Test
    func urlRequestConstruction() throws {
        let client = HTTPClient.liveValue

        let request = try withDependencies {
            $0.hostURL = "website.com/api"
            $0.requestHeaders = [
                .contentType: "application/json",
                .accept: "text-plain"
            ]
        } operation: {
            try client.buildHTTPRequest(url: URL(path: "/users"), method: .post, queryItems: [])
        }

        #expect(request.url?.absoluteString == "https://website.com/api/users")
        #expect(request.method == .post)
        #expect(request.headerFields[.contentType] == "application/json")
        #expect(request.headerFields[.accept] == "text-plain")
    }
    
    // Because the base URL is going to live in a different place than the path, it may not be intuitive where to put slashes
    // These tests verify that no matter how the slashes are placed, the urlRequest is constructed properly

    @Test(arguments: ["users", "/users", "users/", "/users/"])
    func urlConstruction(path: String) throws {
        let components = URLComponents(string: "https://website.com/api/users")!

        let client = HTTPClient.liveValue

        try withDependencies {
            $0.hostURL = "website.com/api"
            $0.requestHeaders = [
                .contentType: "application/json",
                .accept: "text-plain"
            ]
        } operation: {
            let url = try client.buildHTTPRequest(url: URL(path: path), method: .post, queryItems: []).url
            #expect(components.url == url)
        }
    }

    @Test
    func emailEncodesSpecialCharactersCorrectly() throws {
        let client = HTTPClient.liveValue

        let request = try withDependencies {
            $0.hostURL = "api.website.com"
            $0.queryEncoding = .emailEncoding
            $0.requestHeaders = [:]
        } operation: {
            try client.buildHTTPRequest(
                url: URL(path: "/getGlobalUserCounts"),
                method: .get,
                queryItems: [
                    URLQueryItem(name: "email", value: "brendan.blanchard+ssotest1@website.com")
                ]
            )
        }

        #expect(request.url?.absoluteString ==
            "https://api.website.com/getGlobalUserCounts?email=brendan.blanchard%2Bssotest1%40website.com")
    }


    @Test
    func runURLRequest() async throws {
        let client = HTTPClient.liveValue

        try await withDependencies {
            $0.hostURL = "website.com/api"
            $0.requestHeaders = [
                .contentType: "application/json",
                .accept: "text-plain"
            ]

            $0.requestInterceptors = [
                RequestInterceptor { _, _  in
                }
            ]

            $0.responseInterceptors = [
                ResponseInterceptor { _, _, _ in
                }
            ]
            $0.errorInterceptor = nil

            $0.dataForURL = { _, _ in
                (
                    Data(),
                    HTTPResponse(status: 200)
                )
            }

        } operation: {
            let url = try client.buildHTTPRequest(url: URL(path: "/users"), method: .post, queryItems: [])

            _ = try await client.run(url, nil)
        }
    }

    @Test
    func getWithQueryItems() throws {
        let client = HTTPClient.liveValue

        let request = try withDependencies {
            $0.hostURL = "api.example.com"
            $0.requestHeaders = [:]
        } operation: {
            try client.buildHTTPRequest(
                url: URL(path: "/search"),
                method: .get,
                queryItems: [URLQueryItem(name: "q", value: "swift")]
            )
        }

        #expect(request.url?.absoluteString == "https://api.example.com/search?q=swift")
    }

    @Test
    func throwingURLSessionError() async throws {
        let client = HTTPClient.liveValue

        do {

            try await withDependencies {
                $0.hostURL = "website.com/api"
                $0.requestHeaders = [
                    .contentType: "application/json",
                    .accept: "text-plain"
                ]

                $0.requestInterceptors = []
                $0.responseInterceptors = []
                $0.errorInterceptor = nil

                $0.dataForURL = { _, _ in
                    return (Data(), HTTPResponse(status: .unauthorized))
                }

            } operation: {
                let url = try client.buildHTTPRequest(url: URL(path: "/users"), method: .post, queryItems: [])
                _ = try await client.run(url, nil)
            }
        } catch {
            guard let error = error as? HTTPError,
              case let .httpError(code, _, _) = error
            else {
                throw error
            }

            #expect(code == .unauthorized)
        }
    }
}

// MARK: - High-level HTTP method tests

struct HTTPClientRequestTests {

    @Test func getDecodesResponse() async throws {
        struct User: Decodable, Equatable {
            let id: Int
            let name: String
        }

        let client: HTTPClient = .testClient { _, path, method in
            #expect(path == "/users/1")
            #expect(method == .get)
            return #"{"id":1,"name":"Alice"}"#.data(using: .utf8)
        }

        let user: User = try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.get(URL(path: "/users/1"))
        }

        #expect(user == User(id: 1, name: "Alice"))
    }

    @Test func getThrowsExpectedDataResponseWhenEmpty() async throws {
        let client: HTTPClient = .testClient { _, _, _ in nil }

        do {
            let _: String = try await withDependencies {
                $0.hostURL = "api.example.com"
            } operation: {
                try await client.get(URL(path: "/users"))
            }
            reportIssue("Expected HTTPError.expectedDataResponse to be thrown")
        } catch let error as HTTPError {
            guard case .expectedDataResponse = error else { throw error }
        }
    }

    @Test func postEncodesBodyAndDecodesResponse() async throws {
        struct CreateRequest: Codable { let name: String }
        struct CreateResponse: Decodable, Equatable { let id: Int }

        let client: HTTPClient = .testClient { data, path, method -> String in
            #expect(path == "/users")
            #expect(method == .post)
            if let data, let body = try? JSONDecoder().decode(CreateRequest.self, from: data) {
                #expect(body.name == "Alice")
            } else {
                reportIssue("Expected non-nil encoded request body")
            }
            return #"{"id":42}"#
        }

        let response: CreateResponse = try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.post(URL(path: "/users"), data: CreateRequest(name: "Alice"))
        }

        #expect(response == CreateResponse(id: 42))
    }

    @Test func putEncodesBodyAndDecodesResponse() async throws {
        struct UpdateRequest: Codable { let name: String }
        struct UpdateResponse: Decodable, Equatable { let id: Int; let name: String }

        let client: HTTPClient = .testClient { data, path, method -> String in
            #expect(path == "/users/1")
            #expect(method == .put)
            if let data, let body = try? JSONDecoder().decode(UpdateRequest.self, from: data) {
                #expect(body.name == "Bob")
            } else {
                reportIssue("Expected non-nil encoded request body")
            }
            return #"{"id":1,"name":"Bob"}"#
        }

        let response: UpdateResponse = try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.put(URL(path: "/users/1"), data: UpdateRequest(name: "Bob"))
        }

        #expect(response == UpdateResponse(id: 1, name: "Bob"))
    }

    @Test func deleteCallsCorrectEndpoint() async throws {
        nonisolated(unsafe) var deleteCalled = false

        let client: HTTPClient = .testClient { _, path, method in
            #expect(path == "/users/1")
            #expect(method == .delete)
            deleteCalled = true
            return nil
        }

        try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.delete(URL(path: "/users/1"))
        }

        #expect(deleteCalled)
    }

    @Test func pathBasedGetUsesHostURL() async throws {
        struct Item: Decodable, Equatable { let id: Int }

        let client: HTTPClient = .testClient { _, path, method in
            #expect(path == "/items")
            #expect(method == .get)
            return #"{"id":7}"#.data(using: .utf8)
        }

        let item: Item = try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.get("/items")
        }

        #expect(item == Item(id: 7))
    }

    @Test func voidPostSucceeds() async throws {
        nonisolated(unsafe) var called = false

        let client: HTTPClient = .testClient { _, path, method in
            #expect(path == "/action")
            #expect(method == .post)
            called = true
            return nil
        }

        try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.post("/action")
        }

        #expect(called)
    }

    @Test func getWithQueryItemsPassedThrough() async throws {
        struct Result: Decodable, Equatable { let total: Int }

        let client: HTTPClient = .testClient { _, path, method in
            #expect(path == "/search?q=swift")
            return #"{"total":3}"#.data(using: .utf8)
        }

        let result: Result = try await withDependencies {
            $0.hostURL = "api.example.com"
        } operation: {
            try await client.get(URL(path: "/search"), queryItems: [URLQueryItem(name: "q", value: "swift")])
        }

        #expect(result == Result(total: 3))
    }
}

// MARK: - Interceptor tests

struct InterceptorTests {

    @Test func requestInterceptorRunsBeforeRequest() async throws {
        nonisolated(unsafe) var interceptorRan = false

        try await withDependencies {
            $0.hostURL = "api.example.com"
            $0.requestHeaders = [:]
            $0.requestInterceptors = [RequestInterceptor { _, _ in interceptorRan = true }]
            $0.responseInterceptors = []
            $0.errorInterceptor = nil
            $0.dataForURL = { _, _ in (Data(), HTTPResponse(status: 200)) }
        } operation: {
            let request = try HTTPClient.liveValue.buildHTTPRequest(
                url: URL(path: "/test"), method: .get, queryItems: []
            )
            _ = try await HTTPClient.liveValue.run(request, nil)
        }

        #expect(interceptorRan)
    }

    @Test func responseInterceptorReceivesResponseData() async throws {
        let expectedData = #"{"key":"value"}"#.data(using: .utf8)!
        nonisolated(unsafe) var capturedData: Data? = nil

        try await withDependencies {
            $0.hostURL = "api.example.com"
            $0.requestHeaders = [:]
            $0.requestInterceptors = []
            $0.responseInterceptors = [ResponseInterceptor { _, _, data in capturedData = data }]
            $0.errorInterceptor = nil
            $0.dataForURL = { _, _ in (expectedData, HTTPResponse(status: 200)) }
        } operation: {
            let request = try HTTPClient.liveValue.buildHTTPRequest(
                url: URL(path: "/test"), method: .get, queryItems: []
            )
            _ = try await HTTPClient.liveValue.run(request, nil)
        }

        #expect(capturedData == expectedData)
    }

    @Test func errorInterceptorRetriesOnFailure() async throws {
        nonisolated(unsafe) var attemptCount = 0

        try await withDependencies {
            $0.hostURL = "api.example.com"
            $0.requestHeaders = [:]
            $0.requestInterceptors = []
            $0.responseInterceptors = []
            $0.errorInterceptor = ErrorInterceptor(maxRetries: 1) { request, _, _, retry in
                try await retry(request)
            }
            $0.dataForURL = { _, _ in
                let count = attemptCount
                attemptCount += 1
                return count == 0
                    ? (Data(), HTTPResponse(status: .unauthorized))
                    : (Data(), HTTPResponse(status: 200))
            }
        } operation: {
            let request = try HTTPClient.liveValue.buildHTTPRequest(
                url: URL(path: "/test"), method: .get, queryItems: []
            )
            _ = try await HTTPClient.liveValue.run(request, nil)
        }

        #expect(attemptCount == 2)
    }

    @Test func errorInterceptorThrowsWhenRetriesExhausted() async throws {
        try await withDependencies {
            $0.hostURL = "api.example.com"
            $0.requestHeaders = [:]
            $0.requestInterceptors = []
            $0.responseInterceptors = []
            $0.errorInterceptor = ErrorInterceptor(maxRetries: 1) { request, _, _, retry in
                try await retry(request)  // retry once; second failure propagates as HTTPError
            }
            $0.dataForURL = { _, _ in (Data(), HTTPResponse(status: .unauthorized)) }
        } operation: {
            let request = try HTTPClient.liveValue.buildHTTPRequest(
                url: URL(path: "/test"), method: .get, queryItems: []
            )
            do {
                _ = try await HTTPClient.liveValue.run(request, nil)
                reportIssue("Expected HTTPError.httpError to be thrown")
            } catch let error as HTTPError {
                guard case let .httpError(status, _, _) = error else { throw error }
                #expect(status == .unauthorized)
            }
        }
    }
}
