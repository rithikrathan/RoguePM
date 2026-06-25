<!-- LLM GENERATED -->
# Known Problems

## 3. `blocking_lock` on `tokio::sync::Mutex` from a `std::thread`

### Location

- `discover_hosts` (line 149) spawns a `std::thread`
- Lines 162 and 167 call `peers.blocking_lock()` from that thread
- `handle_unix_sockets` (line 111) calls `peers.lock().await` from tokio tasks
- Both share the same `Arc<Mutex<HashMap>>` using `tokio::sync::Mutex`

### The Problem

`tokio::sync::Mutex` is designed for `.lock().await` in async contexts. Calling
`.blocking_lock()` on it from a `std::thread` works mechanically (the thread
blocks until the lock is acquired), but creates a semantic mismatch:

- `tokio::sync::Mutex` uses a `Waker`-based notification system (meant for
  cooperative scheduling within the runtime).
- A `std::thread` doesn't participate in the tokio scheduler, so it's blocked
  at the OS level without yielding to the runtime.
- In a single-threaded tokio runtime, if the std thread holds the lock while
  the tokio task needs it, the runtime can't make progress on other tasks
  running on that same thread until the std thread releases it.

### Potential Outcome

If `handle_unix_sockets` holds the lock (via `lock().await`) when `discover_hosts`
tries to acquire it (via `blocking_lock()`), the std thread blocks. If that
prevents the tokio scheduler from running the task that would release the lock,
it's a deadlock. In practice this is unlikely because both hold times are
microsecond-scale (just HashMap insert/remove), but it's not guaranteed to be
safe.

### Fix

Switch to `std::sync::Mutex` (from `std` or `parking_lot`) instead of
`tokio::sync::Mutex`. Since both access paths just need simple mutual exclusion
with no async coordination, std's mutex is the correct primitive here.

```rust
use std::sync::Mutex;

// then in async code:
peers.lock().unwrap()
// instead of:
peers.lock().await
``C
