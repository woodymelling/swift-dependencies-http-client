
//
//  Result+TryMap.swift
//
//
//  Created by Woodrow Melling on 8/16/23.
//

import Foundation

extension Result where Failure == Error {
    public func tryMap<NewSuccess>(_ transform: (Success) throws -> NewSuccess) -> Result<NewSuccess, Error> {
        self.flatMap { value in
            Result<NewSuccess, Error> { try transform(value) }
        }
    }
}
