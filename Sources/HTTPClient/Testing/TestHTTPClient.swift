//
//  File.swift
//  
//
//  Created by Woodrow Melling on 8/10/23.
//

import Foundation
import Dependencies
import HTTPTypes

extension HTTPClient {
    /**
     A testing rig for testing httpRequests that use an ``HTTPClient``

     This works by allowing a unit test to write code that stands in for a network request that would go to the server.
     Validate whats getting sent to the network, and return data that will be decoded in the application layer.
     It can return data or JSON that will be decoded and handed back to the testcase to validate it's structure

     # Usage

     1. Create an TestHTTPClient, and provide it with a closure that stands in for the network.
     2. In the closure, you should:
        a. that the correct request information was created.
        b. validate the encoded JSON
     3. Return some data from the closure, this can be `Data` or a string of JSON, this will be decoded and returned to the testing function.
     4. Inject it into the code you want to test.
     5. Call the function that depends on the HTTP client
     6. perform some validations of the resulting decoded data.

     ```
     func testCreateUser() async {
         let testFormData = UserFormData(firstName: "Avatar", lastName: "Aang", phoneNumbers: [], email: [])

         // 1
         let client = TestHTTPClient { json, path, method in
             // 2a
             XCTAssertEqual(path, "/users")
             XCTAssertEqual(method, .post)

             // 2b
             try! XCTAssertEqual(
                 json: json,
                 to: [
                     "firstName" : "Avatar",
                     "lastName" : "Aang",
                     "phoneNumbers" : [],
                     "emails" : [],
                     "bleTwoFactorExempt" : false
                    ]
             )

            // 3
             return """
             {
                 "id": 12345,
                 "firstName": "\(testFormData.firstName)",
                 "lastName": "\(testFormData.lastName)"
             }
             """
         }

         // 4
         let dependencyInjectedLiveRepo = LiveUserRepository(httpClient: testHTTPClient)

         // 5
         let result = await dependencyInjectedLiveRepo.createUser(testFormData)

         // 6
         switch result {
         case .success(let success): XCTAssertEqual(success, User.ID(12345))
         case .failure: XCTFail()
         }
     }
     ```
     */
    public static func testClient(getData: @escaping @Sendable (Data?, String, HTTPRequest.Method) throws -> Data?) -> HTTPClient {
        return HTTPClient { request, body in
            try getData(
                body,
                request.url?.pathAndQuery ?? "",
                request.method
            )
        }
    }

    public static func testClient(getData: @escaping @Sendable (Data?, String, HTTPRequest.Method) throws -> String) -> HTTPClient {
        return HTTPClient { request, body in
            try getData(
                body,
                request.url?.pathAndQuery ?? "",
                request.method
            ).data(using: .utf8)
        }
    }
}

extension URL {
    var pathAndQuery: String? {
        var urlString = path()

        if let query {
            urlString += "?\(query)"
        }

        return urlString
    }
}
