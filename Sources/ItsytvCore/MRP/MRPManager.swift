import Foundation
import os.log

private let log = CoreLog(category: "MRP")

/// Orchestrates the MRP protocol lifecycle: connect via AirPlay tunnel, subscribe
/// to now-playing updates, and send media commands.
///
/// Transport encryption is handled by AirPlayMRPTunnel at the AirPlay layer.
/// MRP-level pair-verify is NOT needed when tunneled over AirPlay (pyatv confirms
/// the MRP service has no credentials in this case).
@Observable
public final class MRPManager {
    public var nowPlaying: NowPlayingState?
    public var supportedCommands: Set<MediaCommand> = []
    public var activeAppBundleID: String?
    public var onDisconnect: ((Error?) -> Void)?
    public var onReady: (() -> Void)?
    public var isConnected: Bool { tunnel != nil }

    private var tunnel: AirPlayMRPTunnel?
    private var credentials: HAPCredentials?

    /// Pending response handlers keyed by identifier string
    private var pendingResponses: [String: (MRP_ProtocolMessage?) -> Void] = [:]
    private let responseLock = NSLock()

    /// Playback queue content items and current location (from setStateMessage)
    private var contentItems: [MRP_ContentItem] = []
    private var queueLocation: UInt32 = 0
    private var artworkRequestPending = false
    private var currentContentIdentifier: String?
    private var artworkUnavailable = false

    public init() {}

    // MARK: - Connection lifecycle

    public func connect(host: String, port: UInt16, credentials: HAPCredentials) {
        log.info("MRP connect: \(host):\(port)")
        disconnect()

        self.credentials = credentials

        let tunnel = AirPlayMRPTunnel()
        self.tunnel = tunnel

        tunnel.onDisconnect = { [weak self] error in
            if let error {
                log.error("MRP disconnected: \(error.localizedDescription)")
            } else {
                log.info("MRP disconnected")
            }
            DispatchQueue.main.async {
                self?.tunnel = nil
                self?.nowPlaying = nil
                self?.supportedCommands = []
                self?.onDisconnect?(error)
            }
        }

        tunnel.onMessage = { [weak self] message in
            self?.handleMessage(message)
        }

        tunnel.onReady = { [weak self] in
            log.info("MRP tunnel ready")
            self?.startMRPSession()
        }

        tunnel.connect(host: host, port: port, credentials: credentials)
    }

    public func disconnect() {
        tunnel?.disconnect()
        tunnel = nil
        credentials = nil
        responseLock.lock()
        pendingResponses.removeAll()
        responseLock.unlock()
        contentItems = []
        queueLocation = 0
        artworkRequestPending = false
        artworkUnavailable = false
        currentContentIdentifier = nil
        nowPlaying = nil
        supportedCommands = []
        activeAppBundleID = nil
    }

    // MARK: - Media commands

    public func sendCommand(_ command: MediaCommand) {
        var sendCmd = MRP_SendCommandMessage()
        sendCmd.command = command.mrpCommand

        var message = MRP_ProtocolMessage()
        message.type = .sendCommandMessage
        message.MRP_sendCommandMessage = sendCmd

        tunnel?.send(message)
    }

    /// Send a skip command with a time interval in seconds.
    public func sendSkip(_ command: MediaCommand, interval: Float = 15) {
        var options = MRP_CommandOptions()
        options.skipInterval = interval

        var sendCmd = MRP_SendCommandMessage()
        sendCmd.command = command.mrpCommand
        sendCmd.options = options

        var message = MRP_ProtocolMessage()
        message.type = .sendCommandMessage
        message.MRP_sendCommandMessage = sendCmd

        tunnel?.send(message)
    }

    /// Set volume directly (0.0 = muted, 1.0 = max).
    public func setVolume(_ level: Float) {
        var vol = MRP_SetVolumeMessage()
        vol.volume = level

        var message = MRP_ProtocolMessage()
        message.type = .setVolumeMessage
        message.MRP_setVolumeMessage = vol

        let connected = self.tunnel != nil
        log.info("MRP setVolume: \(level), tunnel: \(connected), hasExt: \(message.hasMRP_setVolumeMessage)")
        tunnel?.send(message)
    }

    /// Re-request the playback queue to get fresh elapsed time (e.g. after returning from background).
    public func refreshNowPlaying() {
        guard tunnel != nil else { return }
        sendPlaybackQueueRequest()
    }

    public func seekToPosition(_ position: Double) {
        var options = MRP_CommandOptions()
        options.playbackPosition = position

        var sendCmd = MRP_SendCommandMessage()
        sendCmd.command = .seekToPlaybackPosition
        sendCmd.options = options

        var message = MRP_ProtocolMessage()
        message.type = .sendCommandMessage
        message.MRP_sendCommandMessage = sendCmd

        tunnel?.send(message)
    }

    // MARK: - Send and receive

    /// Send a message and wait for a response matched by identifier.
    /// If no response arrives within 5 seconds, the handler fires with nil.
    private func sendAndReceive(
        _ message: inout MRP_ProtocolMessage,
        completion: @escaping (MRP_ProtocolMessage?) -> Void
    ) {
        let identifier = UUID().uuidString.uppercased()
        message.identifier = identifier

        responseLock.lock()
        pendingResponses[identifier] = { response in
            completion(response)
        }
        responseLock.unlock()

        let typeDesc = String(describing: message.type)
        log.info("MRP send: \(typeDesc)")
        tunnel?.send(message)

        // Timeout after 5 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.responseLock.lock()
            let handler = self.pendingResponses.removeValue(forKey: identifier)
            self.responseLock.unlock()
            if let handler {
                log.warning("MRP timeout: \(typeDesc)")
                handler(nil)
            }
        }
    }

    private func sendFire(_ message: MRP_ProtocolMessage) {
        tunnel?.send(message)
    }

    // MARK: - Message handling

    private func handleMessage(_ message: MRP_ProtocolMessage) {
        guard message.hasType else { return }
        let type = message.type

        // Check for pending response handler by identifier
        if message.hasIdentifier {
            let id = message.identifier
            responseLock.lock()
            let handler = pendingResponses.removeValue(forKey: id)
            responseLock.unlock()
            if let handler {
                handler(message)
                return
            }
        }

        switch type {
        case .setStateMessage:
            handleSetState(message)
        case .updateContentItemMessage:
            handleUpdateContentItem(message)
        default:
            break
        }
    }

    // MARK: - Session initialization

    private func startMRPSession() {
        sendDeviceInfo { [weak self] _ in
            self?.sendSetConnectionState()
            self?.sendClientUpdatesConfig { _ in
                self?.sendPlaybackQueueRequest()
                self?.tunnel?.startHeartbeat()
                log.info("MRP session initialized")
                self?.onReady?()
            }
        }
    }

    // MARK: - Device info

    private func sendDeviceInfo(completion: @escaping (MRP_ProtocolMessage?) -> Void) {
        guard let credentials else { return }

        var deviceInfo = MRP_DeviceInfoMessage()
        deviceInfo.uniqueIdentifier = credentials.clientID
        deviceInfo.name = "itsytv"
        deviceInfo.localizedModelName = "iPhone"
        deviceInfo.applicationBundleIdentifier = "com.apple.TVRemote"
        deviceInfo.applicationBundleVersion = "344.28"
        deviceInfo.protocolVersion = 1
        deviceInfo.lastSupportedMessageType = 108
        deviceInfo.supportsSystemPairing = true
        deviceInfo.allowsPairing = true
        deviceInfo.supportsAcl = true
        deviceInfo.supportsSharedQueue = true
        deviceInfo.supportsExtendedMotion = true
        deviceInfo.sharedQueueVersion = 2
        deviceInfo.systemMediaApplication = "com.apple.TVMusic"
        deviceInfo.deviceClass = .iPhone
        deviceInfo.logicalDeviceCount = 1

        var msg = MRP_ProtocolMessage()
        msg.type = .deviceInfoMessage
        msg.MRP_deviceInfoMessage = deviceInfo

        sendAndReceive(&msg, completion: completion)
    }

    // MARK: - Set connection state

    private func sendSetConnectionState() {
        var connState = MRP_SetConnectionStateMessage()
        connState.state = .connected

        var msg = MRP_ProtocolMessage()
        msg.type = .setConnectionStateMessage
        msg.MRP_setConnectionStateMessage = connState

        sendFire(msg)
    }

    // MARK: - Client updates config

    private func sendClientUpdatesConfig(completion: @escaping (MRP_ProtocolMessage?) -> Void) {
        var config = MRP_ClientUpdatesConfigMessage()
        config.artworkUpdates = true
        config.nowPlayingUpdates = true
        config.volumeUpdates = true
        config.keyboardUpdates = true
        config.outputDeviceUpdates = true

        var msg = MRP_ProtocolMessage()
        msg.type = .clientUpdatesConfigMessage
        msg.MRP_clientUpdatesConfigMessage = config

        sendAndReceive(&msg, completion: completion)
    }

    // MARK: - Now playing updates

    private func handleSetState(_ message: MRP_ProtocolMessage) {
        guard message.hasMRP_setStateMessage else { return }
        let state = message.MRP_setStateMessage

        if state.hasPlayerPath && state.playerPath.hasClient && state.playerPath.client.hasBundleIdentifier {
            let bundleID = state.playerPath.client.bundleIdentifier
            if !bundleID.isEmpty {
                DispatchQueue.main.async { self.activeAppBundleID = bundleID }
            }
        }

        if state.hasSupportedCommands {
            let cmds = state.supportedCommands.supportedCommands
                .filter { $0.hasEnabled && $0.enabled }
                .compactMap { $0.hasCommand ? MediaCommand($0.command) : nil }
            DispatchQueue.main.async {
                self.supportedCommands = Set(cmds)
                if cmds.isEmpty {
                    self.nowPlaying = nil
                }
            }
        }

        if state.hasPlaybackQueue {
            let queue = state.playbackQueue
            contentItems = queue.contentItems
            queueLocation = queue.hasLocation ? queue.location : 0
            updateNowPlayingFromContentItems()
        }

        if state.hasPlaybackState {
            let pbState = state.playbackState
            DispatchQueue.main.async {
                if pbState == .stopped {
                    self.nowPlaying = nil
                } else if var current = self.nowPlaying {
                    current.playbackRate = (pbState == .playing) ? 1 : 0
                    current.timestamp = Date()
                    self.nowPlaying = current
                } else if pbState == .playing {
                    self.requestArtworkIfNeeded()
                }
            }
        }
    }

    // MARK: - Content item updates

    private func handleUpdateContentItem(_ message: MRP_ProtocolMessage) {
        guard message.hasMRP_updateContentItemMessage else { return }
        let update = message.MRP_updateContentItemMessage

        for item in update.contentItems {
            if item.hasIdentifier,
               let idx = contentItems.firstIndex(where: { $0.hasIdentifier && $0.identifier == item.identifier }) {
                contentItems[idx] = item
            } else {
                contentItems.append(item)
            }
        }

        updateNowPlayingFromContentItems()
    }

    // MARK: - Playback queue request

    /// Request the playback queue with artwork, guarded to prevent concurrent requests.
    private func requestArtworkIfNeeded() {
        guard !artworkRequestPending else {
            log.info("[ART] request skipped, already pending")
            return
        }
        sendPlaybackQueueRequest()
    }

    private func sendPlaybackQueueRequest() {
        var request = MRP_PlaybackQueueRequestMessage()
        request.location = 0
        request.length = 1
        request.includeMetadata = true
        request.artworkWidth = 600
        request.artworkHeight = 600
        request.returnContentItemAssetsInUserCompletion = true

        var msg = MRP_ProtocolMessage()
        msg.type = .playbackQueueRequestMessage
        msg.MRP_playbackQueueRequestMessage = request

        artworkRequestPending = true
        sendAndReceive(&msg) { [weak self] response in
            self?.artworkRequestPending = false
            guard let response, response.hasMRP_setStateMessage else { return }
            self?.handleSetState(response)
        }
    }

    /// Build NowPlayingState from the current content item in the playback queue.
    private func updateNowPlayingFromContentItems() {
        guard !contentItems.isEmpty else {
            currentContentIdentifier = nil
            DispatchQueue.main.async { self.nowPlaying = nil }
            return
        }

        let index = Int(queueLocation)
        let item = index < contentItems.count ? contentItems[index] : contentItems[0]

        guard item.hasMetadata else { return }

        let meta = item.metadata
        let hasContent = meta.hasTitle || meta.hasTrackArtistName || meta.hasAlbumName

        guard hasContent else {
            currentContentIdentifier = nil
            DispatchQueue.main.async { self.nowPlaying = nil }
            return
        }

        let itemID = item.hasIdentifier ? item.identifier : nil
        let contentChanged = itemID != currentContentIdentifier
        currentContentIdentifier = itemID

        if contentChanged {
            artworkUnavailable = false
        }

        let playbackRate = meta.hasPlaybackRate ? meta.playbackRate : (self.nowPlaying?.playbackRate ?? 0)
        let timestamp = Date()

        // Only carry forward artwork if the content item hasn't changed
        let artworkData: Data?
        if item.hasArtworkData {
            artworkData = item.artworkData
            artworkUnavailable = false
            log.info("[ART] has artworkData (\(item.artworkData.count) bytes) contentChanged=\(contentChanged)")
        } else if contentChanged {
            artworkData = nil
            log.info("[ART] content changed, no artwork yet (id=\(itemID ?? "nil"))")
        } else {
            artworkData = self.nowPlaying?.artworkData
            if artworkData == nil {
                artworkUnavailable = true
                log.info("[ART] no artwork, marking unavailable (id=\(itemID ?? "nil"))")
            } else {
                log.info("[ART] carried forward existing artwork (\(artworkData!.count) bytes)")
            }
        }

        let needsArtwork = artworkData == nil && !artworkUnavailable
        log.info("[ART] needsArtwork=\(needsArtwork) artworkUnavailable=\(self.artworkUnavailable) pending=\(self.artworkRequestPending)")

        DispatchQueue.main.async {
            self.nowPlaying = NowPlayingState(
                title: meta.hasTitle ? meta.title : nil,
                artist: meta.hasTrackArtistName ? meta.trackArtistName : nil,
                album: meta.hasAlbumName ? meta.albumName : nil,
                duration: meta.hasDuration ? meta.duration : nil,
                elapsedTime: meta.hasElapsedTime ? meta.elapsedTime : nil,
                playbackRate: playbackRate,
                timestamp: timestamp,
                artworkData: artworkData
            )
            if needsArtwork {
                log.info("[ART] requesting artwork")
                self.requestArtworkIfNeeded()
            }
        }
    }
}
