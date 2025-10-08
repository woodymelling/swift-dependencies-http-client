//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/18/23.
//

import Foundation
import Dependencies

extension URL {

    /// Safely construct a URL, using only the path, and not the baseURL
    /// The baseURL is injected using the `DependencyValues.baseURL`
    /// The URLComponents API has specific expectations for how the baseURL and path are formatted
    /// They aren't documented or intuitive, don't match our use case, and fail silently.
    /// This function should skirt around most of the problems
    init(path: String) throws {

        // Doing some '/' juggling here to safely construct the url.
        // URLComponents expects the host to truly be the base url, with zero path components.
        // This means that a base like `mywebite.com/api` is not a true base url, as `/api` is technically part of the path
        // However, for many reasons, we often want to define our base URL to include the path
        //
        // The below code ensures that regardless of how the caller formats the baseURL and the path,
        // the url gets constructed properly.
        // This means that it should be safe to include or omit leading/trailing slashes on both the path and the baseURL.
        var components = URLComponents()

        @Dependency(\.getHostURL) var getHostURL

        var baseComponents = getHostURL()?.split(separator: "/")

        if baseComponents?.first?.contains("http") ?? false {
            baseComponents?.removeFirst()
        }

        guard let baseURL = baseComponents?.first else {
    //        Logger.httpRequests.log("Could not parse baseURL")
            throw HTTPError.improperURL(components)
        }

        let basePath = Array(baseComponents?.dropFirst() ?? [])
        let pathComponents = path.split(separator: "/")

        components.scheme = "https" // TODO: Inject
        components.host = String(baseURL)
        components.path = "/" + (basePath + pathComponents).joined(separator: "/")

        guard let url = components.url else {
    //        Logger.httpRequests.log("Failed to construct URL from \(components)")
            throw HTTPError.improperURL(components)
        }

        self = url
    }
}


func addQueryItems(_ queryItems: [URLQueryItem], to url: inout URL) {
    @Dependency(\.queryEncoding) var queryEncoding

    if !queryItems.isEmpty {
        if let queryEncoding, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Make sure that query items are properly encoded. So that the server can read them
            // https://swiftunwrap.com/article/url-components-encoding/
            components.percentEncodedQueryItems = queryItems.map {
                var percentEncodedQueryItem = $0
                percentEncodedQueryItem.value = $0.value?
                    .addingPercentEncoding(withAllowedCharacters: queryEncoding.allowedCharacters)

                return percentEncodedQueryItem
            }

            if let newURL = components.url {
                url = newURL
            } else {
                reportIssue("Unable to reconstruct URL")
            }
        } else {
            url.append(queryItems: queryItems)
        }
    }
}


public struct QueryEncoding: Sendable {
    public init(allowedCharacters: CharacterSet) {
        self.allowedCharacters = allowedCharacters
    }
    public var allowedCharacters: CharacterSet
}

extension QueryEncoding {
    public static let emailEncoding = QueryEncoding(allowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: ".")))
}

extension QueryEncoding: DependencyKey {
    public static let liveValue: QueryEncoding? = nil
}

extension DependencyValues {
    public var queryEncoding: QueryEncoding? {
        get { self[QueryEncoding.self] }
        set { self[QueryEncoding.self] = newValue }
    }
}
