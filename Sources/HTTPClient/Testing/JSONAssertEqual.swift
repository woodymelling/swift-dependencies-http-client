//
//  JSONAssertEqual.swift
//  
//
//  Created by Woodrow Melling on 8/14/23.
//

import Foundation
import XCTestDynamicOverlay
import CustomDump

public func expect(
    json data: Data?,
    equalTo dictionary: [String : Any],
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) throws {
    guard let data = data?.jsonDictionary else {
        reportIssue("Expected JSON Data, but found nil")
        return
    }

    // [String:Any] is not equatable, but is a good representation of JSON types.
    // We must convert to NSDictionary, which is equatable somehow.
    expectNoDifference(
        data as NSDictionary,
        dictionary as NSDictionary,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}


extension Data {
    var jsonDictionary: [String: Any]? {
        do {
            let jsonDictonary = try JSONSerialization.jsonObject(
                with: self,
                options: []
            ) as? [String: Any]
            return jsonDictonary
        } catch {
            return nil
        }
    }
}

