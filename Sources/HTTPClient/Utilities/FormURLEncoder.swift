//
//  FormURLEncoder.swift
//  swift-dependencies-http-client
//

import Foundation
import Dependencies
import HTTPTypes

// MARK: - FormURLEncoder

/// Encodes `Encodable` values as `application/x-www-form-urlencoded` data.
/// Supports flat structs only — nested objects and arrays are not supported.
public struct FormURLEncoder: Sendable {
    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = _FormEncoder()
        try value.encode(to: encoder)
        let body = encoder.pairs
            .map { "\(percentEncoded($0.key))=\(percentEncoded($0.value))" }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    // RFC 3986 unreserved characters + characters allowed unescaped in query values
    private static let allowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private func percentEncoded(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: Self.allowedCharacters) ?? string
    }
}

// MARK: - Dependency

public enum FormURLEncoderKey: DependencyKey {
    public static let liveValue = FormURLEncoder()
}

public extension DependencyValues {
    var formEncoder: FormURLEncoder {
        get { self[FormURLEncoderKey.self] }
        set { self[FormURLEncoderKey.self] = newValue }
    }
}

public func withFormEncoding<Input: Encodable, T>(
    body: Input,
    operation: (Data) async throws -> T
) async throws -> T {
    @Dependency(\.formEncoder) var formEncoder
    let data = try formEncoder.encode(body)
    return try await withDependencies {
        $0.requestHeaders[.contentType] = "application/x-www-form-urlencoded"
    } operation: {
        
        try await operation(data)
    }
}


// MARK: - Internal Encoder

private final class _FormEncoder: Encoder {
    var pairs: [(key: String, value: String)] = []
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(_KeyedContainer(encoder: self))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("FormURLEncoder does not support unkeyed containers")
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError("FormURLEncoder does not support top-level single value encoding")
    }
}

private struct _KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _FormEncoder
    var codingPath: [CodingKey] { encoder.codingPath }

    mutating func append(_ key: Key, _ value: String) {
        encoder.pairs.append((key: key.stringValue, value: value))
    }

    mutating func encodeNil(forKey key: Key) throws {}
    mutating func encode(_ value: Bool, forKey key: Key)   throws { append(key, value ? "true" : "false") }
    mutating func encode(_ value: String, forKey key: Key) throws { append(key, value) }
    mutating func encode(_ value: Double, forKey key: Key) throws { append(key, String(value)) }
    mutating func encode(_ value: Float, forKey key: Key)  throws { append(key, String(value)) }
    mutating func encode(_ value: Int, forKey key: Key)    throws { append(key, String(value)) }
    mutating func encode(_ value: Int8, forKey key: Key)   throws { append(key, String(value)) }
    mutating func encode(_ value: Int16, forKey key: Key)  throws { append(key, String(value)) }
    mutating func encode(_ value: Int32, forKey key: Key)  throws { append(key, String(value)) }
    mutating func encode(_ value: Int64, forKey key: Key)  throws { append(key, String(value)) }
    mutating func encode(_ value: UInt, forKey key: Key)   throws { append(key, String(value)) }
    mutating func encode(_ value: UInt8, forKey key: Key)  throws { append(key, String(value)) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { append(key, String(value)) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { append(key, String(value)) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { append(key, String(value)) }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        if let url = value as? URL {
            append(key, url.absoluteString)
            return
        }
        let capture = _SingleValueCapture()
        try value.encode(to: capture)
        if let captured = capture.value {
            append(key, captured)
        }
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        fatalError("FormURLEncoder does not support nested containers")
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        fatalError("FormURLEncoder does not support nested containers")
    }

    mutating func superEncoder() -> Encoder { encoder }
    mutating func superEncoder(forKey key: Key) -> Encoder { encoder }
}

// Captures a single string value from a nested Encodable (e.g. Tagged<_, String>, URL)
private final class _SingleValueCapture: Encoder {
    var value: String?
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        fatalError("FormURLEncoder: unexpected nested keyed container")
    }
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError("FormURLEncoder: unexpected nested unkeyed container")
    }
    func singleValueContainer() -> SingleValueEncodingContainer {
        _SVContainer(encoder: self)
    }
}

private struct _SVContainer: SingleValueEncodingContainer {
    let encoder: _SingleValueCapture
    var codingPath: [CodingKey] { encoder.codingPath }

    mutating func encodeNil() throws {}
    mutating func encode(_ value: Bool)   throws { encoder.value = value ? "true" : "false" }
    mutating func encode(_ value: String) throws { encoder.value = value }
    mutating func encode(_ value: Double) throws { encoder.value = String(value) }
    mutating func encode(_ value: Float)  throws { encoder.value = String(value) }
    mutating func encode(_ value: Int)    throws { encoder.value = String(value) }
    mutating func encode(_ value: Int8)   throws { encoder.value = String(value) }
    mutating func encode(_ value: Int16)  throws { encoder.value = String(value) }
    mutating func encode(_ value: Int32)  throws { encoder.value = String(value) }
    mutating func encode(_ value: Int64)  throws { encoder.value = String(value) }
    mutating func encode(_ value: UInt)   throws { encoder.value = String(value) }
    mutating func encode(_ value: UInt8)  throws { encoder.value = String(value) }
    mutating func encode(_ value: UInt16) throws { encoder.value = String(value) }
    mutating func encode(_ value: UInt32) throws { encoder.value = String(value) }
    mutating func encode(_ value: UInt64) throws { encoder.value = String(value) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        if let url = value as? URL {
            encoder.value = url.absoluteString
        } else {
            let sub = _SingleValueCapture()
            try value.encode(to: sub)
            encoder.value = sub.value
        }
    }
}
