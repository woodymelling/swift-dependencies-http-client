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
