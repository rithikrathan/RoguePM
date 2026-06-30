use serde::{Deserialize, Serialize};

pub type USRequest = serde_json::Value;

#[derive(Serialize, Debug)]
pub struct Response {
    pub res: String,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct PeerInfo {
    pub hostname: String,
    pub fullname: String,
    pub uid: String,
    pub ipv4: String,
    pub trusted: bool,
    pub status: String,
}

// #[derive(Deserialize, Serialize, Debug)]
// pub struct Message {
//     message_type: String,
//     initiated_by: PeerInfo, // sequence initiated by??
//     message: Msg,
//     sid: u8,
// }

// #[derive(Deserialize, Serialize, Debug)]
// pub enum Msg {
//     PairRequest,
//     PairPending,
//     PairAccept,
//     PairReject,
//     Ack,
//     Unpair,
//     Nvm,
//     Dirty,
// }
