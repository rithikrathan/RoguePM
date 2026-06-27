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
    - [x] 2.1 Add deps `tokio-stream`, `gethostname`, and `mdns-sd` with `cargo add`
    - [x] 2.2 Create mDNS daemon (`mdns_sd::ServiceDaemon::new()`)
    - [x] 2.2.1 Optional monitor of the mdns daemon for some errors
    - [x] 2.3 Register `_roguepm._tcp.local` service with hostname and port (`daemon.register(ServiceInfo::new(...))`)
    - [x] 2.4 Browse for `_roguepm._tcp.local` services (`daemon.browse(...)` returns `flume::Receiver<ServiceEvent>`)
    - [x] 2.5 Match `ServiceEvent::ServiceResolved(svc)`, extract hostname and IP (`svc.get_hostname()`, `svc.get_addresses_v4()`, `info!`)
    - [x] 2.6 Spawn socket handler as background task (`tokio::spawn`)
    - [x] 2.7 Keep daemon alive (`ServiceDaemon` is `Clone`, Arc internally — no need for `std::future::pending`)
    - [x] 2.8 Use the `flume::Receiver` from `daemon.browse()` directly (`rx.recv()` sync / `rx.recv_async().await` async)
    - [x] 2.9 Main loop receives and logs peers (`while let Ok(event) = rx.recv()`)
    - [x] 2.10 Build peer table shared across tasks (`Arc<Mutex<HashMap>>`, `Arc::clone`)
    - [x] 2.11 Socket command `list_peers` returns JSON peer table (`serde_json::to_string`)
    - [x] 2.12 Handle `ServiceEvent::ServiceRemoved` — remove from peer table
    - [x] 2.13 Graceful shutdown (`tokio::signal::ctrl_c`, `std::fs::remove_file`)
   
    didnt actually follow this todo but it was a good guideline, i just went with the flow after 2.5 lol, ig i implemented this all idk

## Hello World 3: TCP Handshake + Identity
Discovered peers establish a TCP connection and exchange identity packets (device_id, hostname). Pending pairings are stored in-memory; accepted pairings persist in sled.
- Proves: P2P TCP works, identity exchange works, pairing flow works, persistence works

    - [-] 3.1 Parse CLI args (`clap::Parser`): `--port`, `--socket-path`, `--data-dir`
        * **Look up:** `clap::Parser` macro, `clap::arg` attribute.
        * **Hint:** Use `std::path::PathBuf` for file/socket paths. Use the "Derive Tutorial" in the `clap` docs to see how to map struct fields straight to long arguments using attributes like `#[arg(long, default_value = "...")]`.

    - [ ] 3.2 Init sled DB at data-dir path, generate/load `device_id` via `init_identity()`
        * **Look up:** `sled::open`, `sled::Db::get`, `sled::Db::insert`, `sled::Db::flush_async`.
        * **Hint:** Sled keys/values use `&[u8]`. Convert strings using `.as_bytes()` and parse back using `std::str::from_utf8()`.

    - [ ] 3.3 Load paired peers from sled into `Arc<Mutex<HashMap>>` on startup
        * **Look up:** `std::sync::Arc`, `tokio::sync::Mutex`, `sled::Db::iter`.
        * **Hint:** If operations inside the lock are pure in-memory map updates without `.await` boundaries, consider `parking_lot::Mutex` over `tokio::sync::Mutex` for better performance. Use `sled::Db::iter` to populate the map before spawning loops.

    - [ ] 3.4 Spawn TCP listener on `--port`, log connections, spawn per-connection handler
        * **Look up:** `tokio::net::TcpListener::bind`, `tokio::net::TcpListener::accept`, `tokio::spawn`.
        * **Hint:** Clone the shared state `Arc` *before* moving it into the `tokio::spawn(async move { ... })` block.

    - [ ] 3.5 Implement `tcp_dial()`: connect, send JSON+`\n`, read response line, parse
        * **Look up:** `tokio::net::TcpStream::connect`, `tokio_util::codec::Framed`, `tokio_util::codec::LinesCodec`, `tokio::time::timeout`.
        * **Hint:** Avoid raw byte shifting. Wrap the stream in `Framed::new(stream, LinesCodec::new())` to interact using plain `String` lines over futures `Sink::send` and `StreamExt::next`. Wrap the future in `tokio::time::timeout(Duration::from_secs(5), ...)` to handle the 5s timeout.

    - [ ] 3.6 Handle incoming `pair_request` → store in pending map, reply `pair_pending`
        * **Look up:** `serde::Deserialize`, `serde(tag = "action")` enum attribute, `tokio::sync::MutexGuard`.
        * **Hint:** Look up Serde's "Enum representations" docs—specifically `#[serde(tag = "type")]` (internally tagged enum layout) so you can match directly against incoming JSON commands like `pair_request`.

    - [ ] 3.7 Handle incoming `pair_accept` → move from pending to paired + sled, reply `pair_ack`
        * **Look up:** `std::collections::HashMap::remove`, `std::collections::HashMap::insert`, `sled::Db::insert`.
        * **Hint:** Lock the map, use `HashMap::remove()` on the pending entry, insert it into the paired collection, and execute `sled::Db::insert` to ensure persistence across restarts.

    - [ ] 3.8 Handle incoming `pair_ack` → store in paired + sled
        * **Look up:** `std::collections::HashMap::insert`, `sled::Db::insert`, `sled::Db::flush_async`.
        * **Hint:** Commit the successful pair state to the shared memory map and write it out to the Sled store.

    - [ ] 3.9 Handle incoming `pair_reject` → remove from pending
        * **Look up:** `std::collections::HashMap::remove`.
        * **Hint:** Clean the peer entry out of the transient memory map if the remote target rejects the session.

    - [ ] 3.10 Extend UNIX socket handler: `USRequest` gains optional `hostname` field
        * **Look up:** `serde(default)`, `std::option::Option`.
        * **Hint:** Use Serde attributes like `#[serde(default)]` and `Option<String>` to handle changes gracefully when parsing fields from local CLI wrappers.

    - [ ] 3.11 Implement `pair` UNIX command → `tcp_dial(pair_request)`, respond status
        * **Look up:** `tokio::net::UnixListener`, `tokio::net::UnixStream`.
        * **Hint:** Use `std::fs::remove_file` to clean old unlinked socket files before binding the server path. The Unix handler intercepts the command, triggers the TCP client `tcp_dial()` block, and writes the status back down the pipeline.

    - [ ] 3.12 Implement `accept` UNIX command → `tcp_dial(pair_accept)`, wait `pair_ack`, persist
        * **Look up:** `tokio::select!`.
        * **Hint:** Look up `tokio::select!` documentation to see how to await a TCP network reply from the client channel while managing timeouts or drop cancellations simultaneously.

    - [ ] 3.13 Implement `reject` / `forget` / `pending` UNIX commands
        * **Look up:** Rust Control Flow docs for `match` patterns.
        * **Hint:** Match patterns over enum representations to orchestrate execution routes down your local memory stores.

    - [ ] 3.14 Enhanced `discoverHost` response: return discovered + paired + pending
        * **Look up:** `serde::Serialize`.
        * **Hint:** Structure an aggregated payload object that formats arrays from all three tracking layers into a single serialized response.

    - [ ] 3.15 Edge cases: self-pair check, 5s TCP timeout, re-pair, stale pending cleanup
        * **Look up:** `tokio::time::Duration`, `tokio::time::timeout`, `tokio::time::interval`.
        * **Hint:** For cleanup, run a background loop using `tokio::spawn` and `tokio::time::interval(Duration).tick().await`. Prevent self-pairing by matching remote identifiers against your own state payload properties. 
    
## Hello World 4: TLS Pairing
Daemon generates a self-signed TLS certificate on startup. All TCP communication between paired peers is wrapped in TLS. On first pair, peers pin each other's cert fingerprint (TOFU). Future connections verify the pinned fingerprint.
- Proves: TLS encryption works, trust-on-first-use works, cert pinning persists across restarts

    - [ ] 4.1 Generate self-signed cert + key on startup with `rcgen`. Store key + cert in sled under `my_identity` alongside device_id. If sled already has a cert, load and reuse instead of regenerating each time.
    - [ ] 4.2 Configure `rustls::ServerConfig` with the generated cert + key. Configure `rustls::ClientConfig` that skips standard CA verification (we use our own pinning).
    - [ ] 4.3 Wrap the TCP listener in `tokio_rustls::TlsAcceptor(server_config)`. Accept calls now produce `TlsStream` instead of raw `TcpStream`.
    - [ ] 4.4 Wrap `tcp_dial()` to return a `TlsStream` using `tokio_rustls::TlsConnector(client_config)` before sending/receiving JSON.
    - [ ] 4.5 On first successful TLS handshake with a peer, extract their certificate from the session. Hash the DER-encoded cert (SHA-256) to get a fingerprint. Store it in sled under `paired/{device_id}.cert_fingerprint`.
    - [ ] 4.6 On subsequent connections to an already-paired peer, after the TLS handshake, extract the peer's cert fingerprint and compare against the pinned value. Reject the connection if they don't match (MITM detection).
    - [ ] 4.7 Add `cert_fingerprint: String` field to `PairedPeer`. Update `save_paired_peer` and `load_paired_peers` to handle the new field (backward-compatible: default to empty string if missing).
    - [ ] 4.8 Edge cases: lost cert (regenerate, peer will detect mismatch and re-pair), cert expiry (self-signed, set 10yr expiry), TOFU on re-pair (accept new fingerprint after explicit `forget` + `pair`).

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
