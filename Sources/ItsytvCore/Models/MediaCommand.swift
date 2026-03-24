import Foundation

/// Public-facing media command enum that wraps MRP protocol commands.
/// Decouples app code from the internal protobuf types.
public enum MediaCommand: Hashable, CaseIterable, Sendable {
    case play
    case pause
    case togglePlayPause
    case stop
    case nextTrack
    case previousTrack
    case skipForward
    case skipBackward
    case beginFastForward
    case endFastForward
    case beginRewind
    case endRewind
    case seekToPlaybackPosition
    case advanceShuffleMode
    case advanceRepeatMode
    case changeRepeatMode
    case changeShuffleMode

    var mrpCommand: MRP_Command {
        switch self {
        case .play: return .play
        case .pause: return .pause
        case .togglePlayPause: return .togglePlayPause
        case .stop: return .stop
        case .nextTrack: return .nextTrack
        case .previousTrack: return .previousTrack
        case .skipForward: return .skipForward
        case .skipBackward: return .skipBackward
        case .beginFastForward: return .beginFastForward
        case .endFastForward: return .endFastForward
        case .beginRewind: return .beginRewind
        case .endRewind: return .endRewind
        case .seekToPlaybackPosition: return .seekToPlaybackPosition
        case .advanceShuffleMode: return .advanceShuffleMode
        case .advanceRepeatMode: return .advanceRepeatMode
        case .changeRepeatMode: return .changeRepeatMode
        case .changeShuffleMode: return .changeShuffleMode
        }
    }

    init?(_ mrpCommand: MRP_Command) {
        switch mrpCommand {
        case .play: self = .play
        case .pause: self = .pause
        case .togglePlayPause: self = .togglePlayPause
        case .stop: self = .stop
        case .nextTrack: self = .nextTrack
        case .previousTrack: self = .previousTrack
        case .skipForward: self = .skipForward
        case .skipBackward: self = .skipBackward
        case .beginFastForward: self = .beginFastForward
        case .endFastForward: self = .endFastForward
        case .beginRewind: self = .beginRewind
        case .endRewind: self = .endRewind
        case .seekToPlaybackPosition: self = .seekToPlaybackPosition
        case .advanceShuffleMode: self = .advanceShuffleMode
        case .advanceRepeatMode: self = .advanceRepeatMode
        case .changeRepeatMode: self = .changeRepeatMode
        case .changeShuffleMode: self = .changeShuffleMode
        default: return nil
        }
    }
}
