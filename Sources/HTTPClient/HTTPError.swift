//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/13/23.
//

import Foundation
import HTTPTypes

public enum HTTPError: Error {
    case improperURL(URLComponents)
    case httpError(HTTPResponse.Status, Data?)
    case invalidResponse(String)
    case expectedDataResponse
    case unknown(String)
    case encodingError(Error)
    case decodingError(Error)

    static func httpError(_ response: HTTPResponse.Status) -> Self {
        .httpError(response, nil)
    }
}
