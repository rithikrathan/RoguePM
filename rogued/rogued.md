# rogued — LAN Peer-to-Peer Daemon for RoguePM

## Overview

rogued is the Rust backend daemon for [RoguePM](https://github.com/rithikrathan/RoguePM). It runs in the background on each machine, discovers peers on the local network, and provides a JSON-based control plane via a UNIX socket for the `rogue` bash script to interact with.

## Current Capabilities

- **mDNS Registration** — Advertises itself on the LAN as `_rogued._tcp.local.` with hostname, IP, port, and properties
- **mDNS Discovery** — Browses for other `_rogued._tcp.local.` services and maintains a peer table keyed by device UID
- **UNIX Socket Control** — Listens on `/tmp/rogued.sock` for JSON commands
- **Daemon Monitoring** — Tracks internal mDNS daemon errors
- **Device Identity** — Uses `/etc/machine-id` as unique device identifier

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

The daemon stays alive until Ctrl+C. It cleans up stale socket files on startup and on shutdown.

## Socket Commands

Send JSON commands via the UNIX socket using `socat`:

```bash
echo '<json>' | socat - UNIX-CONNECT:/tmp/rogued.sock
```

The request JSON is parsed dynamically (`serde_json::Value`), so any extra fields beyond `request_type` are preserved and logged.

### Command Reference

| `request_type` | Extra fields | Response | Description |
|---|---|---|---|
| `ping` | — | `{"res":"Pong!"}` | Health check |
| `discoverHost` | — | `{<uid>: <PeerInfo>, ...}` | List discovered peers |
| `pair_request` | `uid` (string) | `{"res":"Request received"}` | Request pairing with a device |
| `pair_reject` | — | _(none)_ | Logs the request |
| `pair_accept` | — | _(none)_ | Logs the request |
| `list_pending` | — | _(none)_ | Logs the request |
| `list_paired` | — | _(none)_ | Logs the request |

### Request Formats

```bash
# Ping
echo '{"request_type":"ping"}' | socat - UNIX-CONNECT:/tmp/rogued.sock
# → {"res":"Pong!"}

# Discover peers
echo '{"request_type":"discoverHost"}' | socat - UNIX-CONNECT:/tmp/rogued.sock
# → {"<uid>":{"hostname":"...","fullname":"...","uid":"...","ipv4":"...","trusted":true,"status":"discovered"}, ...}

# Pair request (by device UID)
echo '{"request_type":"pair_request","uid":"<device-uid>"}' | socat - UNIX-CONNECT:/tmp/rogued.sock
# → {"res":"Request received"}
```

### Response: `discoverHost`

Returns a JSON object keyed by device UID. Each value is a `PeerInfo` struct:

| Field | Type | Description |
|---|---|---|
| `hostname` | string | Clean mDNS hostname (without service type suffix) |
| `fullname` | string | Full mDNS service name (e.g. `host._rogued._tcp.local.`) |
| `uid` | string | Device unique ID from `/etc/machine-id` |
| `ipv4` | string | IPv4 address of the peer |
| `trusted` | bool | Currently hardcoded to `true` |
| `status` | string | Currently `"discovered"` |

## Logging

Log level is controlled in `main.rs`:

```rust
tracing_subscriber::fmt()
    .with_max_level(Level::INFO)  // change to TRACE for verbose debug
    .init();
```

Levels: `ERROR`, `WARN`, `INFO` (default), `DEBUG`, `TRACE`

## Device Identity

- **Machine ID (UID)** — Currently uses `/etc/machine-id` as the device UID. This is a temporary measure; once TLS-based pairing with Trust-On-First-Use (TOFU) is implemented, the UID will be derived from a self-signed certificate fingerprint instead.
- **Hostname** — Retrieved via `gethostname::gethostname()`
- **IP** — Retrieved via `local_ip_address::local_ip()`
- mDNS properties advertised:
  - `not_even_closee` → `"baby"`
  - `technoblade` → `"never_dies!!!!"`
  - `deviceId` → machine-id (used by peers to discover the UID)

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

### Internal Flow

```
main()
  ├── Read /etc/machine-id
  ├── Get hostname + local IP
  ├── Register mDNS service (_rogued._tcp.local.)
  ├── Spawn mDNS daemon monitor
  ├── Spawn task_dispatcher (UNIX socket listener)
  │     └── Accepts connections, reads JSON, dispatches by request_type
  └── discover_hosts (mDNS browsing, runs in std::thread)
        └── Populates peers HashMap on ServiceResolved
```

## Types

### `PeerInfo` (serialized in `discoverHost` response)

| Field | Type | Source |
|---|---|---|
| `hostname` | `String` | Stripped mDNS fullname (without `._rogued._tcp.local.`) |
| `fullname` | `String` | Full mDNS service name |
| `uid` | `String` | `deviceId` property from mDNS TXT record |
| `ipv4` | `String` | Resolved IPv4 address(es), comma-separated |
| `trusted` | `bool` | Hardcoded `true` |
| `status` | `String` | Hardcoded `"discovered"` |

### `Response` (generic success response)

| Field | Type |
|---|---|
| `res` | `String` |

### `USRequest`

Type alias for `serde_json::Value`. Accepted as a dynamic JSON payload — any fields beyond `request_type` are preserved and logged but not validated.

## Known Problems

See [knownproblems.md](./knownproblems.md) for:
- `blocking_lock` on `tokio::sync::Mutex` from a `std::thread` (potential deadlock)

## Vision / Future Roadmap

- **TCP Handshake** — Discovered peers establish on-demand TCP connections
- **TLS Pairing** — Self-signed TLS certificates with Trust-On-First-Use (TOFU) pinning
- **SSH Key Exchange** — Peers exchange ed25519 SSH public keys for passwordless SSHFS mounts
- **List Synchronization** — Share project paths across peers via the daemon
- **Path Lease System** — Per-path distributed locking to prevent write conflicts on mounted SSHFS directories
- **Sled Storage** — Persistent peer cache, identity store, and lease tables via embedded sled database
- **`list_pending` / `list_paired`** — Return pending and paired device lists instead of just logging
- **`pair_reject` / `pair_accept`** — Respond to pairing decisions from peers
