//
//  File.swift
//  
//
//  Created by Woodrow Melling on 12/13/23.
//

import Foundation

public extension Data {
    var prettyJSONString: String {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                return String.init(data: self, encoding: .utf8) ?? "Unable to Decode Value"
            }

            return jsonString

        } catch {
            return String.init(data: self, encoding: .utf8) ?? "Unable to Decode Value"
        }
    }
}
