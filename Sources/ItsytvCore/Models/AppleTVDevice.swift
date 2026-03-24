import Foundation

public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case pairing
    case connected
    case error(String)
}

public struct AppleTVDevice: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16
    public let modelName: String?

    public init(id: String, name: String, host: String, port: UInt16, modelName: String?) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.modelName = modelName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AppleTVDevice, rhs: AppleTVDevice) -> Bool {
        lhs.id == rhs.id
    }
}
