import Foundation
import Network
import os.log

private let log = CoreLog(category: "Discovery")

/// Discovers Apple TV devices via Bonjour _companion-link._tcp and resolves their TXT records
/// to filter by device type (rpFl flags).
final class DeviceDiscovery: NSObject {
    private var browser: NetServiceBrowser?
    private var onChange: (([AppleTVDevice]) -> Void)?
    private var services: [String: NetService] = [:]
    private var devices: [String: AppleTVDevice] = [:]
    private var retryTimer: Timer?

    func start(onChange: @escaping ([AppleTVDevice]) -> Void) {
        self.onChange = onChange
        startBrowsing()
        startRetryLoop()
    }

    func refresh() {
        restartBrowsing()
        knockLastDevice()
    }

    /// Stop browsing and timer but keep discovered devices.
    func pause() {
        retryTimer?.invalidate()
        retryTimer = nil
        browser?.stop()
        browser = nil
    }

    func stop() {
        pause()
        services.removeAll()
        devices.removeAll()
    }

    /// Returns all resolved services with their TXT records for debugging.
    func allResolvedServices() -> [[String: Any]] {
        services.values.compactMap { service in
            guard let txtData = service.txtRecordData() else { return nil }
            let txtDict = NetService.dictionary(fromTXTRecord: txtData)
            var props: [String: String] = [:]
            for (key, value) in txtDict {
                if let str = String(data: value, encoding: .utf8) {
                    props[key] = str
                }
            }
            return [
                "name": service.name,
                "host": service.hostName ?? "",
                "port": service.port,
                "txt": props,
            ] as [String: Any]
        }
    }

    // MARK: - Browsing

    private func startBrowsing() {
        let b = NetServiceBrowser()
        b.delegate = self
        b.searchForServices(ofType: "_companion-link._tcp.", inDomain: "local.")
        self.browser = b
    }

    private func restartBrowsing() {
        browser?.stop()
        startBrowsing()
    }

    // MARK: - Retry loop

    /// Periodically restart the browser to catch devices that were
    /// sleeping or missed due to dropped mDNS packets.
    private func startRetryLoop() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.restartBrowsing()
        }
    }

    // MARK: - Port knocking

    /// Knock on common Apple TV ports to wake devices from deep sleep.
    /// Sleeping devices use a Bonjour sleep proxy; a TCP connection attempt
    /// wakes them so they re-advertise their own services.
    private func knockLastDevice() {
        guard let device = LastConnectedDeviceStorage.load(),
              !device.host.isEmpty else { return }
        let host = device.host.hasSuffix(".") ? String(device.host.dropLast()) : device.host
        let ports: [UInt16] = [3689, 7000, 49152, 49153]
        log.info("Knocking \(host) on ports \(ports)")
        for port in ports {
            knockPort(host: host, port: port)
        }
    }

    private func knockPort(host: String, port: UInt16) {
        DispatchQueue.global(qos: .utility).async {
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global(qos: .utility))
            // Cancel after 0.5s regardless
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
                connection.cancel()
            }
        }
    }

    // MARK: - Processing

    fileprivate func notifyChange() {
        let current = Array(devices.values)
        DispatchQueue.main.async { [weak self] in
            self?.onChange?(current)
        }
    }

    fileprivate func processResolved(_ service: NetService) {
        guard let txtData = service.txtRecordData() else {
            log.info("No TXT data for \(service.name)")
            return
        }

        let txtDict = NetService.dictionary(fromTXTRecord: txtData)
        var props: [String: String] = [:]
        for (key, value) in txtDict {
            if let str = String(data: value, encoding: .utf8) {
                props[key] = str
            }
        }

        let modelName = props["rpMd"]
        let flagStr = props["rpFl"] ?? "0x0"
        let flags = UInt64(flagStr.replacingOccurrences(of: "0x", with: ""), radix: 16) ?? 0

        log.info("Resolved: \(service.name) model=\(modelName ?? "nil") flags=0x\(String(flags, radix: 16))")

        // Only show devices that support PIN pairing (Apple TVs).
        // HomePods, Macs, iPads etc. don't have the 0x4000 flag.
        guard flags & 0x4000 != 0 else {
            devices.removeValue(forKey: service.name)
            notifyChange()
            return
        }

        // Service name is the stable device ID. rpBA rotates due to BLE privacy
        // and cannot be used as a persistent key for keychain/settings.
        let device = AppleTVDevice(
            id: service.name,
            name: service.name,
            host: service.hostName ?? "",
            port: UInt16(service.port),
            modelName: modelName
        )
        devices[service.name] = device
        notifyChange()
    }

}

extension DeviceDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        log.info("Found service: \(service.name)")
        services[service.name] = service
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        log.info("Removed service: \(service.name)")
        services.removeValue(forKey: service.name)
        devices.removeValue(forKey: service.name)
        notifyChange()
    }
}

extension DeviceDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        processResolved(sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        log.warning("Failed to resolve \(sender.name): \(errorDict)")
    }
}
