import Foundation

/// Credentials stored after successful pair-setup.
public struct HAPCredentials: Codable {
    public let clientLTSK: Data   // Ed25519 private key (32 bytes)
    public let clientLTPK: Data   // Ed25519 public key (32 bytes)
    public let clientID: String   // Client pairing UUID
    public let serverLTPK: Data   // Apple TV's Ed25519 public key (32 bytes)
    public let serverID: String   // Apple TV's identifier

    public init(clientLTSK: Data, clientLTPK: Data, clientID: String, serverLTPK: Data, serverID: String) {
        self.clientLTSK = clientLTSK
        self.clientLTPK = clientLTPK
        self.clientID = clientID
        self.serverLTPK = serverLTPK
        self.serverID = serverID
    }
}
