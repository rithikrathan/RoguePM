# rogued — LAN Peer-to-Peer Daemon for RoguePM

## Overview

rogued is the Rust backend daemon for [RoguePM](https://github.com/rithikrathan/RoguePM). It runs in the background on each machine, discovers peers on the local network, and provides a JSON-based control plane via a UNIX socket for the `rogue` bash script to interact with.

## Current Capabilities

- **mDNS Registration** — Advertises itself on the LAN as `_rogued._tcp.local.` with hostname, IP, and port
- **mDNS Discovery** — Browses for other `_rogued._tcp.local.` services and maintains a peer table (`hostname → IP` map)
- **UNIX Socket Control** — Listens on `/tmp/rogued.sock` for JSON commands
- **Daemon Monitoring** — Tracks internal mDNS daemon errors

## Building

```bash
cd rogued/
cargo build              # debug build
cargo build --release    # release build with LTO + stripping
```

## Running

```bash
./target/debug/rogued          # foreground (Ctrl+C to stop)
./target/release/rogued        # release build
```

The daemon stays alive until Ctrl+C. It cleans up the socket file on startup.

## Socket Commands

Send JSON commands via the UNIX socket using `socat`:

```bash
echo '{"request_type":"ping"}' | socat - UNIX-CONNECT:/tmp/rogued.sock
# Response: {"res":"Pong!"}

echo '{"request_type":"discoverHost"}' | socat - UNIX-CONNECT:/tmp/rogued.sock
# Response: prints the peer hashmap (hostname -> IP string)
```

### Command Reference

| `request_type` | Response | Description |
|---|---|---|
| `ping` | `{"res":"Pong!"}` | Health check |
| `discoverHost` | prints peer table | List discovered peers |

## Logging

Log level is controlled in `main.rs`:

```rust
tracing_subscriber::fmt()
    .with_max_level(Level::INFO)  // change to TRACE for verbose debug
    .init();
```

Levels: `ERROR`, `WARN`, `INFO` (default), `DEBUG`, `TRACE`

## Architecture

```
┌─────────────┐     UNIX Socket      ┌────────────────┐
│  rogue.sh   │ ◄─────────────────►  │    rogued      │
│ (bash CLI)  │   /tmp/rogued.sock   │  (Rust daemon) │
└─────────────┘                      └────────┬───────┘
                                              │
                                    mDNS (port 5353)
                                              │
                                      ┌───────┴───────┐
                                      │   LAN Peers   │
                                      └───────────────┘
```

## Vision / Future Roadmap

- **TCP Handshake** — Discovered peers establish on-demand TCP connections
- **TLS Pairing** — Self-signed TLS certificates with Trust-On-First-Use (TOFU) pinning
- **SSH Key Exchange** — Peers exchange ed25519 SSH public keys for passwordless SSHFS mounts
- **List Synchronization** — Share project paths across peers via the daemon
- **Path Lease System** — Per-path distributed locking to prevent write conflicts on mounted SSHFS directories
- **Sled Storage** — Persistent peer cache, identity store, and lease tables via embedded sled database
