//
//  SSLPinning.swift
//  Rocket
//
//  Created as part of the Rocket module.
//

import Foundation

/// Protocol defining an SSL pinning strategy
public protocol SSLPinningStrategy {
    /// Create a URLSessionDelegate that implements SSL pinning
    func createSessionDelegate() -> URLSessionDelegate?
}

/// Strategy for disabling SSL pinning
public final class SSLPinningDisabledStrategy: SSLPinningStrategy {
    public init() {}

    public func createSessionDelegate() -> URLSessionDelegate? {
        // Return nil to use the default URLSession delegate
        return nil
    }
}

/// Strategy for enabling SSL pinning with specific certificates
public final class SSLPinningEnabledStrategy: SSLPinningStrategy {
    private let domain: String
    private let certificateNames: [String]

    /// Initialize with domain and certificate names
    /// - Parameters:
    ///   - domain: The domain to validate certificates for
    ///   - certificateNames: Array of certificate file names (without extension)
    public init(domain: String, certificateNames: [String] = []) {
        self.domain = domain
        self.certificateNames = certificateNames
    }

    public func createSessionDelegate() -> URLSessionDelegate? {
        return SSLPinningDelegate(domain: domain, certificateNames: certificateNames)
    }
}

/// URLSessionDelegate implementation that handles SSL pinning
private final class SSLPinningDelegate: NSObject, URLSessionDelegate {
    private let domain: String
    private var certificates: [SecCertificate] = []

    init(domain: String, certificateNames: [String]) {
        self.domain = domain
        super.init()

        // Load certificates
        for name in certificateNames {
            if let certificatePath = Bundle.main.path(forResource: name, ofType: "cer"),
                let certificateData = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)),
                let certificate = SecCertificateCreateWithData(nil, certificateData as CFData)
            {
                certificates.append(certificate)
            }
        }
    }

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Check if this is a server trust challenge for our domain
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == domain,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            // For other domains or challenge types, use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // If we have no certificates to validate against, use default handling
        if certificates.isEmpty {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Set the anchor certificates for validation
        let policy = SecPolicyCreateSSL(true, domain as CFString)
        SecTrustSetAnchorCertificates(serverTrust, certificates as CFArray)
        SecTrustSetPolicies(serverTrust, [policy] as CFArray)

        // Evaluate the trust
        var isValid = false
        if #available(iOS 13.0, macOS 10.15, *) {
            // Use newer API on iOS 13+ and macOS 10.15+
            var error: CFError?
            isValid = SecTrustEvaluateWithError(serverTrust, &error)
        } else {
            // Use deprecated API for backward compatibility
            var result: SecTrustResultType = .invalid
            SecTrustEvaluate(serverTrust, &result)
            isValid = (result == .proceed || result == .unspecified)
        }

        if isValid {
            // Certificate is valid, proceed with the connection
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Certificate validation failed, cancel the connection
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
