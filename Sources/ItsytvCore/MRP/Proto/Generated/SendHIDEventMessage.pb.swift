// Manually created to match pyatv's SendHIDEventMessage.proto
// SendHIDEventMessage { optional bytes hidEventData = 1; }
// Extension on ProtocolMessage: field 13

import Foundation
import SwiftProtobuf

struct MRP_SendHIDEventMessage: Sendable {
    var hidEventData: Data {
        get { return _hidEventData ?? Data() }
        set { _hidEventData = newValue }
    }
    var hasHidEventData: Bool { return _hidEventData != nil }
    mutating func clearHidEventData() { _hidEventData = nil }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _hidEventData: Data?
}

// MARK: - ProtocolMessage extension accessors

extension MRP_ProtocolMessage {
    var MRP_sendHIDEventMessage: MRP_SendHIDEventMessage {
        get { return getExtensionValue(ext: MRP_Extensions_sendHIDEventMessage) ?? MRP_SendHIDEventMessage() }
        set { setExtensionValue(ext: MRP_Extensions_sendHIDEventMessage, value: newValue) }
    }
    var hasMRP_sendHIDEventMessage: Bool {
        return hasExtensionValue(ext: MRP_Extensions_sendHIDEventMessage)
    }
    mutating func clearMRP_sendHIDEventMessage() {
        clearExtensionValue(ext: MRP_Extensions_sendHIDEventMessage)
    }
}

// MARK: - Extension object (global, matching existing pattern)

let MRP_Extensions_sendHIDEventMessage = SwiftProtobuf.MessageExtension<SwiftProtobuf.OptionalMessageExtensionField<MRP_SendHIDEventMessage>, MRP_ProtocolMessage>(
    _protobuf_fieldNumber: 13,
    fieldName: "sendHIDEventMessage"
)

// MARK: - SwiftProtobuf conformance

extension MRP_SendHIDEventMessage: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "SendHIDEventMessage"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{01}hidEventData\0")

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularBytesField(value: &_hidEventData)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try { if let v = _hidEventData {
            try visitor.visitSingularBytesField(value: v, fieldNumber: 1)
        } }()
        try unknownFields.traverse(visitor: &visitor)
    }

    static func ==(lhs: MRP_SendHIDEventMessage, rhs: MRP_SendHIDEventMessage) -> Bool {
        if lhs._hidEventData != rhs._hidEventData { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
