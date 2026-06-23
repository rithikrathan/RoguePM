HELLO IDIOTS!: This is OBVIOUSLY a llm generated plan

# rogued — Hello World Steps
Each step is independently testable.

## Hello World 1: UNIX Socket Ping/Pong
Daemon listens on `/tmp/rogued.sock`. Bash sends `{"cmd":"ping"}`. Daemon replies `{"pong":true}`.
- Proves: socket works, JSON works, daemon lifecycle works, bash talks to daemon
    - [x] 1.1 Remove old socket file if exists (`std::fs::remove_file`)
    - [x] 1.2 Bind `UnixListener` to `/tmp/rogued.sock`
    - [x] 1.3 Accept a connection in a loop
    - [x] 1.4 Read all bytes from the stream (`read_to_end`)
    - [x] 1.5 Parse JSON into `Request { cmd: String }` (`serde_json::from_slice`)
    - [x] 1.6 Check if `cmd == "ping"`
    - [x] 1.7 Build `Response { pong: true }` and serialize (`serde_json::to_string`)
    - [x] 1.8 Write JSON bytes back to the stream (`write_all`)
    - [x] 1.9 Spawn each connection handler with `tokio::spawn`
    - [x] 1.10 Test with `socat` from another terminal

## Hello World 2: mDNS Discovery
Two daemon instances discover each other via mDNS. Each prints/logs the peer's hostname and IP.
- Proves: mDNS registration + browsing works, spawn/channel refactor, shared state with Arc<Mutex>
    - [ ] 2.1 Add deps `tokio-stream` and `gethostname` with `cargo add`
    - [ ] 2.2 Get mDNS daemon handle (`libmdns::daemon()`)
    - [ ] 2.3 Register `_roguepm._tcp` service with hostname and port (`responder.register()`)
    - [ ] 2.4 Browse for `_roguepm._tcp` services (`responder.browse()`, `StreamExt::next().await`)
    - [ ] 2.5 Extract hostname and IP on `NewService` (`svc.hostname()`, `svc.addresses()`, `info!`)
    - [ ] 2.6 Spawn socket handler as background task (`tokio::spawn`)
    - [ ] 2.7 Spawn mDNS tasks as background, keep handles alive with `std::future::pending`
    - [ ] 2.8 Create mpsc channel, wire browser → main (`mpsc::channel`, `tx.send().await`)
    - [ ] 2.9 Main loop receives and logs peers (`rx.recv().await`, `while let Some`)
    - [ ] 2.10 Build peer table shared across tasks (`Arc<Mutex<HashMap>>`, `Arc::clone`)
    - [ ] 2.11 Socket command `list_peers` returns JSON peer table (`serde_json::to_string`)
    - [ ] 2.12 Handle `RemoveService` — remove from table, notify main via `PeerEvent` enum
    - [ ] 2.13 Graceful shutdown (`tokio::signal::ctrl_c`, `std::fs::remove_file`)

## Hello World 3: TCP Handshake + Identity
Discovered peers establish a TCP connection and exchange identity packets (device_id, hostname).
- Proves: P2P TCP works, identity exchange works

## Hello World 4: TLS Pairing
Identity packets include self-signed TLS certs. Peers pin each other's certs (TOFU).
- Proves: TLS encryption works, trust-on-first-use works

## Hello World 5: SSH Key Exchange
Daemon generates ed25519 keypair. During pairing, peers exchange SSH pubkeys.
Each writes the peer's pubkey to `~/.ssh/authorized_keys` (scoped).
- Proves: SSHFS passwordless auth setup works

## Hello World 6: List Sync
Peers exchange their project paths (from ~/Desktop/projects + rp.list).
Each stores the peer's list in sled. Bash queries via `rogue list --remote`.
- Proves: list sync works, per-peer storage works

## Hello World 7: Path Lease
Daemon A requests mount permission for Daemon B's path. B grants/denies based on lease table.
Lease has TTL. Idle timeout forces release.
- Proves: distributed path locking works
