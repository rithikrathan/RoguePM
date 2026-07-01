use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;

pub type USRequest = serde_json::Value;

#[derive(Serialize, Debug)]
pub struct Response {
    pub res: String,
}

#[derive(Clone, Deserialize, Serialize, Debug)]
pub struct PeerInfo {
    pub hostname: String,
    pub fullname: String,
    pub uid: String,
    pub ipv4: String,
    pub trusted: bool,
    pub status: String,
}

#[derive(Debug, PartialEq, Clone)]
pub enum State {
    Initial,
    WaitingForPeerAck,
    WaitingForUserResponse,
    PendingCommit,
    Paired,
}

#[derive(Serialize, Deserialize, Debug)]
pub enum PeerMessage {
    PairRequest { uid: String },
    RequestAck,
    PairAccept,
    CommitAck,
    PairReject,
    SyncProjectList(Vec<String>),
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub enum UnixCommand {
    AcceptPairing(String), // Contains target peer UID
    RejectPairing(String),
    InitiatePairing(String), // Contains target IP/Port
}

pub type ActiveConnections = Arc<DashMap<String, mpsc::Sender<UnixCommand>>>;
