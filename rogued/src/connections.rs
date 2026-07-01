use crate::types::{ActiveConnections, PeerMessage, State, UnixCommand};
use bytes::Bytes;
use futures::{SinkExt, StreamExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::mpsc;
use tokio_util::codec::{Framed, LengthDelimitedCodec};
use tracing::{error, info};

pub async fn pairing_actor(
    tcp_stream: TcpStream,
    my_uid: String,
    mut unix_rx: mpsc::Receiver<UnixCommand>,
    db: sled::Db,
    roster: ActiveConnections,
    tx: mpsc::Sender<UnixCommand>,
    is_initiator: bool,
) {
    let mut framed = Framed::new(tcp_stream, LengthDelimitedCodec::new());
    let mut state = State::Initial;
    let mut peer_uid = String::new();

    if is_initiator {
        let req = PeerMessage::PairRequest {
            uid: my_uid.clone(),
        };
        let payload = Bytes::from(serde_json::to_vec(&req).unwrap());
        if framed.send(payload).await.is_err() {
            return;
        }
        state = State::WaitingForPeerAck;
    }

    loop {
        tokio::select! {
            Some(Ok(bytes)) = framed.next() => {
                let msg: PeerMessage = match serde_json::from_slice(&bytes) {
                    Ok(m) => m,
                    Err(e) => {
                        error!("Failed to deserialize PeerMessage: {}", e);
                        break;
                    }
                };

                match (&state, msg) {
                    (State::Initial, PeerMessage::PairRequest { ref uid }) => {
                        peer_uid = uid.clone();
                        roster.insert(uid.clone(), tx.clone());

                        let ack = Bytes::from(serde_json::to_vec(&PeerMessage::RequestAck).unwrap());
                        if framed.send(ack).await.is_err() { break; }
                        state = State::WaitingForUserResponse;
                    }

                    (State::WaitingForPeerAck, PeerMessage::RequestAck) => {}

                    (State::WaitingForPeerAck, PeerMessage::PairAccept) => {
                        db.insert(peer_uid.as_bytes(), b"paired").unwrap();
                        let ack = Bytes::from(serde_json::to_vec(&PeerMessage::CommitAck).unwrap());
                        if framed.send(ack).await.is_err() { break; }
                        state = State::Paired;
                        info!("Paired with {}", peer_uid);
                    }

                    (State::PendingCommit, PeerMessage::CommitAck) => {
                        db.insert(peer_uid.as_bytes(), b"paired").unwrap();
                        state = State::Paired;
                        info!("Paired with {}", peer_uid);
                    }

                    (_, PeerMessage::PairReject) => { break; }

                    (State::Paired, PeerMessage::SyncProjectList(data)) => {
                        info!("Received project list from {}: {:?}", peer_uid, data);
                    }

                    _ => {
                        error!("Protocol violation in state {:?}", state);
                        break;
                    }
                }
            }

            Some(cmd) = unix_rx.recv() => {
                match (&state, cmd) {
                    (State::WaitingForUserResponse, UnixCommand::AcceptPairing(_)) => {
                        db.insert(peer_uid.as_bytes(), b"pending_commit").unwrap();
                        let msg = Bytes::from(serde_json::to_vec(&PeerMessage::PairAccept).unwrap());
                        if framed.send(msg).await.is_err() { break; }
                        state = State::PendingCommit;
                    }

                    (State::WaitingForUserResponse, UnixCommand::RejectPairing(_)) => {
                        let msg = Bytes::from(serde_json::to_vec(&PeerMessage::PairReject).unwrap());
                        let _ = framed.send(msg).await;
                        break;
                    }

                    _ => {}
                }
            }

            _ = tokio::time::sleep(std::time::Duration::from_secs(60)), if state != State::Paired => {
                if state == State::PendingCommit {
                    let _ = db.remove(peer_uid.as_bytes());
                }
                break;
            }
        }
    }

    if !peer_uid.is_empty() {
        roster.remove(&peer_uid);
    }
}

pub async fn tcp_server_loop(
    port: u16,
    my_uid: String,
    db: sled::Db,
    roster: ActiveConnections,
) -> std::io::Result<()> {
    let listener = TcpListener::bind(format!("0.0.0.0:{}", port)).await?;
    info!("TCP listener on port {}", port);

    loop {
        match listener.accept().await {
            Ok((stream, _addr)) => {
                let (tx, rx) = mpsc::channel(32);
                let db = db.clone();
                let my_uid = my_uid.clone();
                let roster = roster.clone();

                tokio::spawn(async move {
                    pairing_actor(stream, my_uid, rx, db, roster, tx, false).await;
                });
            }
            Err(e) => {
                error!("TCP accept error: {}", e);
            }
        }
    }
}

pub async fn initiate_connection(
    target_addr: String,
    _peer_uid: String,
    my_uid: String,
    db: sled::Db,
    roster: ActiveConnections,
    tx: mpsc::Sender<UnixCommand>,
    rx: mpsc::Receiver<UnixCommand>,
) {
    match TcpStream::connect(&target_addr).await {
        Ok(stream) => {
            info!("Connected to {}", target_addr);
            pairing_actor(stream, my_uid, rx, db, roster, tx, true).await;
        }
        Err(e) => {
            error!("Failed to connect to {}: {}", target_addr, e);
        }
    }
}
