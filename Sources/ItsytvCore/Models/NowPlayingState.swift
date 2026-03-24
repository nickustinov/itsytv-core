import Foundation

public struct NowPlayingState {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var duration: TimeInterval?
    public var elapsedTime: TimeInterval?
    public var playbackRate: Float
    public var timestamp: Date
    public var artworkData: Data?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        duration: TimeInterval? = nil,
        elapsedTime: TimeInterval? = nil,
        playbackRate: Float,
        timestamp: Date,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.timestamp = timestamp
        self.artworkData = artworkData
    }

    public var isPlaying: Bool { playbackRate > 0 }

    public var currentPosition: TimeInterval {
        guard let elapsed = elapsedTime else { return 0 }
        return elapsed + Date().timeIntervalSince(timestamp) * Double(playbackRate)
    }
}
