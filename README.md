# Rocket

A lightweight, modular networking framework for Swift applications.

## Features

- Modern Swift-based networking with async/await support
- Protocol-oriented design for flexibility and testability
- Configurable SSL certificate pinning
- Automatic token refresh handling
- Comprehensive error handling
- Modular architecture for easy integration
- Network connectivity monitoring
- Logging capabilities
- File upload support

## Requirements

- iOS 14.0+ / macOS 12.0+
- Swift 5.6+
- Xcode 13.0+

## Installation

### Swift Package Manager

Add Rocket as a dependency to your Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/ahmadMNT/Rocket", .upToNextMajor(from: "1.0.0"))
]
```

## Basic Usage

### Setting up the NetworkManager

```swift
// Create a simple network manager
let networkManager = NetworkManager.withoutSSLPinning(
    tokenManager: MyTokenManager(),
    logger: MyNetworkLogger()
)

// Or with SSL pinning
let secureNetworkManager = NetworkManager.withSSLPinning(
    domain: "api.example.com",
    certificateNames: ["example-cert"],
    tokenManager: MyTokenManager(),
    logger: MyNetworkLogger()
)
```

### Creating your endpoints

```swift
// Define your application-specific endpoints
enum AppEndpoint: APIEndpoint {
    case login(username: String, password: String)
    case getUser(id: Int)
    
    var path: String {
        switch self {
        case .login: return "/auth/login"
        case .getUser: return "/users"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .login: return .post
        case .getUser: return .get
        }
    }
    
    var queryParameters: [URLQueryItem] {
        switch self {
        case .getUser(let id):
            return [URLQueryItem(name: "id", value: "\(id)")]
        default:
            return []
        }
    }
    
    var bodyParameters: [String: Any]? {
        switch self {
        case let .login(username, password):
            return ["username": username, "password": password]
        default:
            return nil
        }
    }
    
    var authenticationCredentials: AuthenticationCredentials {
        switch self {
        case .login:
            return .none
        case .getUser:
            return .bearer(token: "your-token-here")
        }
    }
}
```

### Making API requests

```swift
// Using async/await
func fetchUser(id: Int) async {
    let result: Result<User, NetworkError> = await networkManager.performRequest(to: AppEndpoint.getUser(id: id))
    
    switch result {
    case .success(let user):
        // Handle success
        print("User: \(user)")
    case .failure(let error):
        // Handle error
        print("Error: \(error.message)")
    }
}
```

## Advanced Configuration

### Custom Response Processing

You can create custom response processors to handle specialized API formats:

```swift
class MyResponseProcessor: ResponseProcessorProtocol {
    func process<T: Decodable>(data: Data, response: URLResponse) throws -> Result<T, NetworkError> {
        // Your custom implementation
    }
}

// Use your custom processor
let networkManager = NetworkManager(
    tokenManager: myTokenManager,
    logger: myLogger,
    responseProcessor: MyResponseProcessor()
)
```

### Custom Token Management

```swift
class MyTokenManager: TokenManaging {
    func currentToken() -> String? {
        // Return the current token
    }
    
    func refreshToken() async throws {
        // Refresh the token
    }
}
```

## License

Rocket is available under the MIT license. 
