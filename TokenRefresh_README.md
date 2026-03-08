# Token Refresh System Refactor

## Overview
The token refresh system has been refactored to be simpler, more reliable, and inheritable for custom implementations.

## Key Changes

### 1. New Protocol: `TokenRefreshHandler`
```swift
public protocol TokenRefreshHandler {
    func refreshToken() async throws
}
```

### 2. Simplified Logic
- Token refresh is now only attempted **once** per request cycle
- Clear separation between refresh logic and retry logic
- Better error handling and state management

### 3. Inheritance Support
You can now implement your own token refresh logic by conforming to `TokenRefreshHandler`.

## Usage Examples

### Default Behavior (No Changes Needed)
```swift
let networkManager = NetworkManager(
    tokenManager: tokenManager,
    logger: logger
)
// Uses existing tokenManager.refreshToken() automatically
```

### Custom Token Refresh Handler
```swift
class MyCustomRefreshHandler: TokenRefreshHandler {
    func refreshToken() async throws {
        // Call your custom refresh token API
        let response = try await myAPIService.refreshToken()
        // Save new tokens
        tokenStorage.saveTokens(response.accessToken, response.refreshToken)
    }
}

let networkManager = NetworkManager(
    tokenManager: tokenManager,
    logger: logger,
    tokenRefreshHandler: MyCustomRefreshHandler()
)
```

## Key Features

### ✅ Only Called Once
- `hasAttemptedTokenRefresh` flag ensures refresh is only attempted once per request
- Prevents infinite loops when refresh fails

### ✅ Simple API
- Clean protocol for custom implementations
- Minimal configuration required

### ✅ Backward Compatible
- Existing code continues to work without changes
- Default behavior uses existing `TokenManaging.refreshToken()`

### ✅ Configurable
- `tokenRefreshErrorTypes` can be customized
- Custom handlers can implement any refresh logic

## Files Modified

### Core Changes
- `NetworkManager.swift` - Refactored token refresh logic
- Added `TokenRefreshHandler` protocol
- Simplified `handleRequestFailure` method

### New Examples
- `CustomTokenRefreshHandler.swift` - Example implementation
- `TokenRefreshUsage.swift` - Usage examples

## Migration Guide

### No Migration Required
Existing code will continue to work without any changes.

### For Custom Implementations
If you want to use your own refresh token API:

1. Create a class conforming to `TokenRefreshHandler`
2. Implement `refreshToken()` method with your API call
3. Pass it to NetworkManager's `tokenRefreshHandler` parameter

### Example Migration
```swift
// Before (if you were subclassing NetworkManager)
class MyNetworkManager: NetworkManager {
    override func refreshToken() async throws {
        // custom logic
    }
}

// After (cleaner separation)
class MyRefreshHandler: TokenRefreshHandler {
    func refreshToken() async throws {
        // custom logic
    }
}

let networkManager = NetworkManager(
    tokenManager: tokenManager,
    logger: logger,
    tokenRefreshHandler: MyRefreshHandler()
)
```

## Benefits

1. **Simplicity** - Clear, focused responsibility
2. **Reliability** - Guaranteed single refresh attempt
3. **Flexibility** - Easy to customize and extend
4. **Maintainability** - Better separation of concerns
5. **Testability** - Easy to mock and test custom handlers
