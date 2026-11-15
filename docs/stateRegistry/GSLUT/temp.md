# GSLUT On-Demand Construction Proposals

Discussion on constructing the Global State Lookup Table dynamically without persistent memory locks or daemon bloat.

---

## Core Problem
- The daemon should not keep heavy lookup tables or resource locks constantly in memory while idle.
- Querying must be fast enough for interactive CLI commands (`rogue open`, `rogue list`).

---

## Architectural Proposals

### Approach 1: Parallel Fan-Out with Strict Timeout
- When a command like `rogue open` runs:
  1. Instantly loads local projects from the local Sled database (`Index 0`).
  2. Dispatches parallel asynchronous network requests across all active peer sockets.
  3. Uses a strict millisecond timeout (e.g., 50-100ms) to gather remote lists.
  4. Merges returned peer projects with local projects on the fly.
  5. Drops the assembled table from memory as soon as selection finishes.

### Approach 2: Heartbeat-Cached Peer Summaries
- The background daemon maintains lightweight socket heartbeats with known peers.
- During heartbeats, peers exchange lightweight project metadata summaries, cached as raw buffers.
- When `rogue open` runs, it reads the local database and the daemon's cached peer buffers instantly with zero network waiting.
