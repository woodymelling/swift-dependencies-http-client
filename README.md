# HTTPClient

A lightweight, dependency-injectable HTTP client for Swift applications built on top of Foundation's URLSession and HTTPTypes.

## Overview

HTTPClient provides a clean, testable interface for making HTTP requests with support for request/response interception, automatic retry logic, and comprehensive error handling. It's designed around the swift-dependencies library for easy testing and configuration.

## Features

- **Lightweight**: Minimal wrapper around URLSession with HTTPTypes integration
- **Dependency Injectable**: Built with swift-dependencies for easy testing and configuration
- **Request/Response Interception**: Pluggable interceptors for modifying requests and responses
- **Automatic Retry Logic**: Built-in error handling with configurable retry attempts
- **Type-Safe**: Full support for Codable types with automatic JSON encoding/decoding
- **Comprehensive HTTP Methods**: Support for GET, POST, PUT, and DELETE operations
- **Path-Based API**: Convenient methods that work with base URLs and relative paths

## Installation

Add HTTPClient to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/woodymelling/swift-dependencies-http-client", from: "1.0.0")
]
```

## Basic Usage

### Making Requests

```swift
import HTTPClient
import Dependencies

// GET request with automatic JSON decoding
let user: User = try await httpClient.get(
    URL(string: "https://api.example.com/users/123")!
)

// POST request with JSON body
let newUser = CreateUserRequest(name: "John", email: "john@example.com")
let createdUser: User = try await httpClient.post(
    URL(string: "https://api.example.com/users")!,
    data: newUser
)

// PUT request
let updatedUser: User = try await httpClient.put(
    URL(string: "https://api.example.com/users/123")!,
    data: updateData
)

// DELETE request
try await httpClient.delete(
    URL(string: "https://api.example.com/users/123")!
)
```

### Path-Based API

When you have a base URL configured, you can use path-based methods:

```swift
// These methods automatically prepend your configured base URL
let user: User = try await httpClient.get("/users/123")
let users: [User] = try await httpClient.get("/users", queryItems: [
    URLQueryItem(name: "page", value: "1")
])
```

### Query Parameters

```swift
let queryItems = [
    URLQueryItem(name: "page", value: "1"),
    URLQueryItem(name: "limit", value: "20")
]

let users: [User] = try await httpClient.get(
    URL(string: "https://api.example.com/users")!,
    queryItems: queryItems
)
```

## Configuration

### Dependency Injection

HTTPClient is designed to work with the swift-dependencies library:

```swift
import Dependencies

// In your app code
@Dependency(\.httpClient) var httpClient

// Configure in tests
withDependencies {
    $0.httpClient = .mock
} operation: {
    // Your test code here
}
```

### Request Interceptors

Implement custom request interceptors to modify requests before they're sent:

```swift
struct AuthorizationInterceptor: RequestInterceptor {
    func run(_ request: inout HTTPRequest, _ body: inout Data?) async throws {
        request.headerFields[.authorization] = "Bearer \(token)"
    }
}
```

### Response Interceptors

Implement response interceptors to handle responses:

```swift
struct LoggingInterceptor: ResponseInterceptor {
    func run(
        _ request: HTTPRequest, 
        _ response: inout HTTPResponse, 
        _ data: inout Data?
    ) async throws {
        print("Response: \(response.status)")
    }
}
```

### Error Handling

Configure automatic retry logic with error interceptors:

```swift
struct RetryInterceptor: ErrorInterceptor {
    let maxRetries = 3
    
    func interceptor(
        _ request: HTTPRequest,
        _ status: HTTPResponse.Status,
        _ data: Data?,
        _ retry: @escaping (HTTPRequest) async throws -> Data?
    ) async throws -> Data? {
        // Custom retry logic
        if status == .serviceUnavailable {
            return try await retry(request)
        }
        throw HTTPError.httpError(status)
    }
}
```

## Testing

HTTPClient is built for testability. Override the underlying data fetching mechanism in tests:

```swift
withDependencies {
    $0.dataForURL = { request, data in
        // Return mock response data
        let mockData = """
        {"id": 1, "name": "Test User"}
        """.data(using: .utf8)!
        
        let response = HTTPResponse(status: .ok)
        return (mockData, response)
    }
} operation: {
    // Your test code here
}
```

## Error Handling

HTTPClient throws `HTTPError` for various error conditions:

- `HTTPError.httpError(status)`: For non-successful HTTP status codes
- `HTTPError.expectedDataResponse`: When a GET request returns no data

## Dependencies

This library depends on:

- **Foundation**: Core Swift framework
- **HTTPTypes**: Apple's HTTP types library
- **HTTPTypesFoundation**: Foundation integration for HTTPTypes
- **Dependencies**: Point-Free's dependency injection library
- **OSLog**: For internal logging

## Requirements

- Swift 5.9+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+

## License

[Your License Here]

## Contributing

[Contributing guidelines here]
