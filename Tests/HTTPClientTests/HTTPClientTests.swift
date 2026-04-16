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

        #expect(request.url?.absoluteString == "https://pi.website.com/api/users")
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
                    #expect(true)
                }
            ]

            $0.responseInterceptors = [
                ResponseInterceptor { _, _, _ in
                    #expect(true)
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
            guard let error = error as? HTTPError, case let .httpError(code, _) = error else {
                throw error
            }
            #expect(code == .unauthorized)
        }
    }
}
