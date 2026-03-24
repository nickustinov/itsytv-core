// Manually created to match pyatv's SetVolumeMessage.proto
// SetVolumeMessage { optional float volume = 1; optional string outputDeviceUID = 2; }
// Extension on ProtocolMessage: field 55

import SwiftProtobuf

struct MRP_SetVolumeMessage: Sendable {
    var volume: Float {
        get { return _volume ?? 0 }
        set { _volume = newValue }
    }
    var hasVolume: Bool { return _volume != nil }
    mutating func clearVolume() { _volume = nil }

    var outputDeviceUID: String {
        get { return _outputDeviceUID ?? "" }
        set { _outputDeviceUID = newValue }
    }
    var hasOutputDeviceUID: Bool { return _outputDeviceUID != nil }
    mutating func clearOutputDeviceUID() { _outputDeviceUID = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _volume: Float?
    fileprivate var _outputDeviceUID: String?
}

// MARK: - ProtocolMessage extension accessors

extension MRP_ProtocolMessage {
    var MRP_setVolumeMessage: MRP_SetVolumeMessage {
        get { return getExtensionValue(ext: MRP_Extensions_setVolumeMessage) ?? MRP_SetVolumeMessage() }
        set { setExtensionValue(ext: MRP_Extensions_setVolumeMessage, value: newValue) }
    }
    var hasMRP_setVolumeMessage: Bool {
        return hasExtensionValue(ext: MRP_Extensions_setVolumeMessage)
    }
    mutating func clearMRP_setVolumeMessage() {
        clearExtensionValue(ext: MRP_Extensions_setVolumeMessage)
    }
}

// MARK: - Extension object (global, matching existing pattern)

let MRP_Extensions_setVolumeMessage = SwiftProtobuf.MessageExtension<SwiftProtobuf.OptionalMessageExtensionField<MRP_SetVolumeMessage>, MRP_ProtocolMessage>(
    _protobuf_fieldNumber: 55,
    fieldName: "setVolumeMessage"
)

// MARK: - SwiftProtobuf conformance

extension MRP_SetVolumeMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "SetVolumeMessage"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{01}volume\0\u{01}outputDeviceUID\0")

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularFloatField(value: &_volume)
            case 2: try decoder.decodeSingularStringField(value: &_outputDeviceUID)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try { if let v = _volume {
            try visitor.visitSingularFloatField(value: v, fieldNumber: 1)
        } }()
        try { if let v = _outputDeviceUID {
            try visitor.visitSingularStringField(value: v, fieldNumber: 2)
        } }()
        try unknownFields.traverse(visitor: &visitor)
    }

    static func ==(lhs: MRP_SetVolumeMessage, rhs: MRP_SetVolumeMessage) -> Bool {
        if lhs._volume != rhs._volume { return false }
        if lhs._outputDeviceUID != rhs._outputDeviceUID { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
