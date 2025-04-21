//
//  Reachability.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation
import Network

/// Class for monitoring network connectivity
public final class Reachability {
    /// Shared singleton instance
    public static let shared = Reachability()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworKitReachabilityMonitor")
    private var isMonitoring = false
    
    /// Current connection status
    private(set) var isConnected = false
    
    private init() {}
    
    /// Start monitoring network connectivity
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.isConnected = path.status == .satisfied
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network connectivity
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
    }
    
    /// Check for a real internet connection by making a test request
    /// - Returns: True if the internet connection is available
    public func checkInternetConnection() async -> Bool {
        // First check basic connectivity
        guard isConnected else {
            return false
        }
        
        // Then try to make a real connection to verify
        let testURL = URL(string: "https://www.apple.com")!
        
        do {
            let (_, _) = try await URLSession.shared.data(from: testURL)
            return true
        } catch {
            return false
        }
    }
} 
