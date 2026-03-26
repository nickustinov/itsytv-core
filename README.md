# itsytv-core

[![Tests](https://github.com/nickustinov/itsytv-core/actions/workflows/tests.yml/badge.svg)](https://github.com/nickustinov/itsytv-core/actions/workflows/tests.yml)
[![Swift 5.10](https://img.shields.io/badge/swift-5.10-orange.svg)](https://swift.org)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen.svg)](https://www.apple.com/macos/sonoma/)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://www.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Swift package implementing the Apple TV Companion Link and AirPlay 2 protocols. Powers [itsytv for macOS](https://github.com/nickustinov/itsytv-macos) and itsytv for iOS.

## What it does

- **Device discovery** – finds Apple TVs on the local network via Bonjour
- **Pairing** – SRP-based pair-setup (PIN entry) and pair-verify with Keychain-backed credential storage
- **Remote control** – HID button commands (d-pad, select, menu, home, play/pause, volume)
- **Text input** – live keyboard input to Apple TV text fields
- **Now playing** – artwork, title, artist, progress, and playback state via MRP protobuf messages
- **App launching** – launch installed apps and fetch their icons from the App Store
- **AirPlay 2 tunnel** – HAP-encrypted AirPlay control channel with MRP transport

## Architecture

```
Sources/ItsytvCore/
├── Discovery/            # Bonjour device discovery
├── Protocol/
│   ├── AppleTVManager    # Orchestrator: discovery -> pairing -> session -> commands
│   ├── CompanionConnection / CompanionFrame  # TCP framing
│   ├── CompanionCommands # HID buttons, session start, app launching
│   ├── TextInputSession  # Live text input
│   ├── OPACK             # Apple's OPACK binary serialization
│   ├── BinaryPlist       # Binary plist with NSKeyedArchiver UIDs
│   └── TLV8              # TLV8 encoding for HomeKit-style pairing
├── Crypto/
│   ├── PairSetup         # SRP pair-setup flow (M1-M6)
│   ├── PairVerify        # Pair-verify flow (M1-M4)
│   ├── CompanionCrypto   # ChaCha20-Poly1305 session encryption
│   ├── CryptoHelpers     # Nonce padding, HKDF-SHA512
│   └── KeychainStorage   # Secure credential persistence
├── AirPlay/
│   ├── AirPlayControlChannel  # HTTP/RTSP with pair-verify and HAP encryption
│   ├── AirPlayPairVerify      # Pair-verify over AirPlay HTTP
│   ├── AirPlayMRPTunnel       # MRP transport over AirPlay 2
│   ├── DataStreamChannel      # MRP protobuf framing
│   ├── HAPChannel / HAPSession # HAP-encrypted TCP
├── MRP/
│   ├── MRPManager        # Now-playing state and media commands
│   └── Proto/Generated/  # Protobuf Swift code
├── Models/               # AppleTVDevice, NowPlayingState, HAPCredentials, MediaCommand
└── Utilities/            # AppIconFetcher, AppOrderStorage
```

## Usage

Add the package as a dependency:

```swift
.package(path: "../itsytv-core")
```

```swift
import ItsytvCore

let manager = AppleTVManager()
// manager handles discovery, pairing, and connection automatically
```

## Requirements

- Swift 5.10+
- macOS 14.0+ or iOS 17.0+

## Testing

```bash
swift test
```

## License

MIT License (c) 2026 Nick Ustinov – see [LICENSE](LICENSE) for details.

## Acknowledgements

Protocol implementation informed by [pyatv](https://github.com/postlund/pyatv), the comprehensive Python library for Apple TV control.
