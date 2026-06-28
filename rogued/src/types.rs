use serde::{Deserialize, Serialize};

#[derive(Deserialize, Debug)]
pub struct USRequest {
    pub request_type: String,
}

#[derive(Serialize, Debug)]
pub struct Response {
    pub res: String,
}

#[derive(Deserialize, Serialize, Debug)]
pub struct _PeerInfo {
    hostname: String,
    uuid: u16,
    ipv4: String,
    trusted: bool,
    status: String,
}
