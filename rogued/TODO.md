HELLO IDIOTS!: This is OBVIOUSLY a llm generated plan

# rogued — Hello World Steps
Each step is independently testable.

## Hello World 1: UNIX Socket Ping/Pong
Daemon listens on `/tmp/rogued.sock`. Bash sends `{"cmd":"ping"}`. Daemon replies `{"pong":true}`.
- Proves: socket works, JSON works, daemon lifecycle works, bash talks to daemon
    - [x] Remove old socket file if exists (`std::fs::remove_file`)
    - [x] Bind `UnixListener` to `/tmp/rogued.sock`
    - [x] Accept a connection in a loop
    - [x] Read all bytes from the stream (`read_to_end`)
    - [x] Parse JSON into `Request { cmd: String }` (`serde_json::from_slice`)
    - [x] Check if `cmd == "ping"`
    - [x] Build `Response { pong: true }` and serialize (`serde_json::to_string`)
    - [x] Write JSON bytes back to the stream (`write_all`)
    - [ ] Spawn each connection handler with `tokio::spawn`
    - [ ] Test with `socat` from another terminal

## Hello World 2: mDNS Discovery
Two daemon instances discover each other via mDNS. Each prints/logs the peer's hostname and IP.
- Proves: mDNS registration + browsing works

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
