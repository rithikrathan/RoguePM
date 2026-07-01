use dashmap::DashMap;
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use std::collections::HashMap;
use std::io::ErrorKind;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;
use tokio::sync::{Mutex, mpsc};
use tracing::{Level, error, info};

mod connections;
mod types;
use connections::{initiate_connection, tcp_server_loop};
use types::{ActiveConnections, PeerInfo, Response, USRequest, UnixCommand};

static SOCKET_BIND_PATH: &str = "/tmp/rogued.sock";
static MDNS_SERVICE_TYPE: &str = "_rogued._tcp.local.";
static INCLUDE_SELF: bool = false;
static TCP_PORT: u16 = 5200;

async fn task_dispatcher(
    peers: Arc<Mutex<HashMap<String, PeerInfo>>>,
    roster: ActiveConnections,
    db: sled::Db,
    my_uid: String,
) -> std::io::Result<()> {
    let listener = match UnixListener::bind(SOCKET_BIND_PATH) {
        Ok(l) => l,
        Err(e) => {
            error!("Owned by skill issue, \r\nError: {}", e);
            return Err(e);
        }
    };

    loop {
        match listener.accept().await {
            Ok((mut stream, _addr)) => {
                let peers = Arc::clone(&peers);
                let roster = roster.clone();
                let db = db.clone();
                let my_uid = my_uid.clone();

                tokio::spawn(async move {
                    info!("Unix Socket connected");
                    let mut input_data = Vec::new();
                    if let Err(e) = stream.read_to_end(&mut input_data).await {
                        error!(
                            "While reading the input stream from the socket connection: \r\n{e}"
                        );
                    }

                    let serialized_request: USRequest = match serde_json::from_slice(&input_data) {
                        Ok(ser) => ser,
                        Err(e) => {
                            error!("Error while Deserialization: \r\n {}", e);
                            return;
                        }
                    };

                    let req_type = serialized_request["request_type"].as_str().unwrap_or("");
                    match req_type {
                        "ping" => {
                            info!("{:?}", serialized_request);
                            let response = Response {
                                res: "Pong!".to_string(),
                            };
                            let serialized_response = match serde_json::to_vec(&response) {
                                Ok(ser) => ser,
                                Err(e) => {
                                    error!("Error while Serialization: \r\n {}", e);
                                    return;
                                }
                            };
                            if let Err(e) = stream.write_all(&serialized_response).await {
                                error!(
                                    "While writing to the output stream of the socket connection: \r\n{e}"
                                );
                            }
                        }

                        "discoverHost" => {
                            info!("{:?}", serialized_request);
                            let locked = peers.lock().await;
                            let serialized_response = match serde_json::to_string(&*locked) {
                                Ok(ser) => ser,
                                Err(e) => {
                                    error!("Error while Serialization: \r\n {}", e);
                                    return;
                                }
                            };
                            if let Err(e) = stream.write_all(serialized_response.as_bytes()).await {
                                error!(
                                    "While writing to the output stream of the socket connection: \r\n{e}"
                                );
                            }
                        }

                        "pair_request" => {
                            info!("{:#?}", serialized_request); // log incomming request
                            // get target uid
                            let target_uid =
                                serialized_request["uid"].as_str().unwrap_or("").to_string();

                            // validate input
                            if target_uid.is_empty() {
                                let response = Response {
                                    res: "Error: No UID provided".to_string(),
                                };
                                let _ = stream
                                    .write_all(&serde_json::to_vec(&response).unwrap())
                                    .await;
                                return;
                            }

                            // get peer info with the uid as the key
                            let peer_info = {
                                let locked = peers.lock().await;
                                locked.get(&target_uid).cloned()
                            };

                            // handle peer info if its available, else send  peerNotFound message to
                            // the frontend
                            match peer_info {
                                Some(info) => {
                                    // get ip if peer is available
                                    let first_ip = info
                                        .ipv4
                                        .split(',')
                                        .next()
                                        .unwrap_or("")
                                        .trim()
                                        .to_string();

                                    // validate ip entry
                                    if first_ip.is_empty() {
                                        let response = Response {
                                            res: "Error: No IP for peer".to_string(),
                                        };
                                        let _ = stream
                                            .write_all(&serde_json::to_vec(&response).unwrap())
                                            .await;
                                        return;
                                    }

                                    // concatenate ip with its port to make a full address
                                    let addr = format!("{}:{}", first_ip, TCP_PORT);
                                    let (tx, rx) = mpsc::channel(32); // to communicate betweeen
                                    // threads??
                                    roster.insert(target_uid.clone(), tx.clone());
                                    // initiates a pair handler/actor
                                    tokio::spawn(initiate_connection(
                                        addr,
                                        target_uid.clone(),
                                        my_uid.clone(),
                                        db.clone(),
                                        roster.clone(),
                                        tx,
                                        rx,
                                    ));

                                    // send response to the frontend
                                    let response = Response {
                                        res: format!("Pairing request sent to {}", target_uid),
                                    };

                                    //send response lol
                                    let _ = stream
                                        .write_all(&serde_json::to_vec(&response).unwrap())
                                        .await;
                                }

                                None => {
                                    // send peer not found response
                                    let response = Response {
                                        res: format!("Error: Peer '{}' not found", target_uid),
                                    };

                                    //send response lol
                                    let _ = stream
                                        .write_all(&serde_json::to_vec(&response).unwrap())
                                        .await;
                                }
                            }
                        }

                        "pair_accept" => {
                            info!("{:?}", serialized_request); // log incomming request for debug

                            // get UID from request and clean it
                            let target_uid = serialized_request["uid"]
                                .as_str()
                                .filter(|s| !s.is_empty())
                                .map(|s| s.to_string())
                                .or_else(|| {
                                    let hostname = serialized_request["hostname"].as_str()?;
                                    let locked = peers.blocking_lock();
                                    locked
                                        .iter()
                                        .find(|(_, info)| info.hostname == hostname)
                                        .map(|(uid, _)| uid.clone())
                                })
                                .unwrap_or_default();

                            // validate UID
                            if target_uid.is_empty() {
                                let response = Response {
                                    res: "Error: No UID or hostname provided".to_string(),
                                };
                                let _ = stream
                                    .write_all(&serde_json::to_vec(&response).unwrap())
                                    .await;
                                return;
                            }

                            // get host from active connections what are initiated previously
                            match roster.get(&target_uid) {
                                Some(actor_tx) => {
                                    if actor_tx
                                        .send(UnixCommand::AcceptPairing(target_uid.clone()))
                                        .await
                                        .is_err()
                                    {
                                        // send response to the peer and if error execte this block
                                        let response = Response {
                                            // report error to the frontend
                                            res: "Error: Peer actor unreachable".to_string(),
                                        };
                                        let _ = stream
                                            .write_all(&serde_json::to_vec(&response).unwrap())
                                            .await;
                                    } else {
                                        let response = Response {
                                            // send success response to the frontend
                                            res: "Accept sent".to_string(),
                                        };
                                        let _ = stream
                                            .write_all(&serde_json::to_vec(&response).unwrap())
                                            .await;
                                    }
                                }

                                None => {
                                    // if no connections are initiated for this peer then report to
                                    // the frontend, ask it to initiate a connection using
                                    // rogue daemon pair -u <uid>
                                    let response = Response {
                                        res: format!(
                                            "Error: No active connection to {}",
                                            target_uid
                                        ),
                                    };
                                    let _ = stream
                                        .write_all(&serde_json::to_vec(&response).unwrap())
                                        .await;
                                }
                            }
                        }

                        "pair_reject" => {
                            // pretty much the same as the previous "pair_accept" request
                            info!("{:?}", serialized_request);
                            let target_uid = serialized_request["uid"]
                                .as_str()
                                .filter(|s| !s.is_empty())
                                .map(|s| s.to_string())
                                .or_else(|| {
                                    let hostname = serialized_request["hostname"].as_str()?;
                                    let locked = peers.blocking_lock();
                                    locked
                                        .iter()
                                        .find(|(_, info)| info.hostname == hostname)
                                        .map(|(uid, _)| uid.clone())
                                })
                                .unwrap_or_default();

                            if target_uid.is_empty() {
                                let response = Response {
                                    res: "Error: No UID or hostname provided".to_string(),
                                };
                                let _ = stream
                                    .write_all(&serde_json::to_vec(&response).unwrap())
                                    .await;
                                return;
                            }

                            match roster.get(&target_uid) {
                                Some(actor_tx) => {
                                    if actor_tx
                                        .send(UnixCommand::RejectPairing(target_uid.clone()))
                                        .await
                                        .is_err()
                                    {
                                        let response = Response {
                                            res: "Error: Peer actor unreachable".to_string(),
                                        };
                                        let _ = stream
                                            .write_all(&serde_json::to_vec(&response).unwrap())
                                            .await;
                                    } else {
                                        let response = Response {
                                            res: "Reject sent".to_string(),
                                        };
                                        let _ = stream
                                            .write_all(&serde_json::to_vec(&response).unwrap())
                                            .await;
                                    }
                                }
                                None => {
                                    let response = Response {
                                        res: format!(
                                            "Error: No active connection to {}",
                                            target_uid
                                        ),
                                    };
                                    let _ = stream
                                        .write_all(&serde_json::to_vec(&response).unwrap())
                                        .await;
                                }
                            }
                        }

                        "list_pending" => {
                            // get connections from the "roaster" and send list json to the frontend
                            info!("{:?}", serialized_request);
                            let pending_uids: Vec<String> =
                                roster.iter().map(|entry| entry.key().clone()).collect();
                            let response = Response {
                                res: serde_json::to_string(&pending_uids).unwrap(),
                            };
                            let serialized_response = match serde_json::to_vec(&response) {
                                Ok(ser) => ser,
                                Err(e) => {
                                    error!("Error while Serialization: \r\n {}", e);
                                    return;
                                }
                            };
                            if let Err(e) = stream.write_all(&serialized_response).await {
                                error!(
                                    "While writing to the output stream of the socket connection: \r\n{e}"
                                );
                            }
                        }

                        "list_paired" => {
                            info!("{:?}", serialized_request);
                            // get connections from the "roaster" and send list json to the frontend
                            let paired: Vec<String> = db
                                .iter()
                                .filter_map(|res| {
                                    res.ok()
                                        .map(|(key, _)| String::from_utf8_lossy(&key).to_string())
                                })
                                .collect();
                            let response = Response {
                                res: serde_json::to_string(&paired).unwrap(),
                            };
                            let serialized_response = match serde_json::to_vec(&response) {
                                Ok(ser) => ser,
                                Err(e) => {
                                    error!("Error while Serialization: \r\n {}", e);
                                    return;
                                }
                            };
                            if let Err(e) = stream.write_all(&serialized_response).await {
                                error!(
                                    "While writing to the output stream of the socket connection: \r\n{e}"
                                );
                            }
                        }

                        _ => {
                            error!("Something phishy... \r\n{:#?}", serialized_request);
                        }
                    }
                });
            }
            Err(e) => {
                error!("Error when accepting socket connection, \r\n{}", e);
            }
        }
    }
}

async fn discover_hosts(
    mdns: &ServiceDaemon,
    peers: Arc<Mutex<HashMap<String, PeerInfo>>>,
    self_fullname: String,
) -> std::io::Result<()> {
    let mdns_receiver = mdns.browse(MDNS_SERVICE_TYPE).unwrap();
    std::thread::spawn(move || {
        while let Ok(event) = mdns_receiver.recv() {
            match event {
                ServiceEvent::ServiceResolved(serv_resolved) => {
                    info!("Service resolved: {}", serv_resolved.get_hostname());

                    let ip_str = serv_resolved
                        .get_addresses_v4()
                        .iter()
                        .map(|ip| ip.to_string())
                        .collect::<Vec<_>>()
                        .join(", ");

                    let uid = serv_resolved
                        .get_property("deviceId")
                        .map(|s| s.val_str())
                        .unwrap_or("unknown");

                    if serv_resolved.get_fullname().to_string() == *self_fullname && !INCLUDE_SELF {
                        continue;
                    }

                    let cleaned_hostname: String = serv_resolved
                        .get_fullname()
                        .strip_suffix(&format!(".{}", MDNS_SERVICE_TYPE))
                        .unwrap()
                        .to_string();

                    peers.blocking_lock().insert(
                        uid.to_string(),
                        PeerInfo {
                            hostname: cleaned_hostname,
                            fullname: serv_resolved.get_fullname().to_string(),
                            uid: uid.to_string(),
                            ipv4: ip_str.into(),
                            trusted: true,
                            status: "discovered".into(),
                        },
                    );
                }

                ServiceEvent::ServiceRemoved(_, fullname) => {
                    info!("Service removed: {}", fullname);
                    peers
                        .blocking_lock()
                        .retain(|_, info| info.fullname != fullname);
                }

                ServiceEvent::SearchStopped(ty_domain) => {
                    info!("mDNS search stopped for: {}", ty_domain);
                    break;
                }

                _ => {}
            }
        }
    });
    Ok(())
}

#[tokio::main]
async fn main() -> std::io::Result<()> {
    println!("Hello Idiots!");

    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    let device_id = std::fs::read_to_string("/etc/machine-id")
        .map(|s| s.trim().to_string())
        .expect("/etc/machine-id not found");

    let peers: Arc<Mutex<HashMap<String, PeerInfo>>> = Arc::new(Mutex::new(HashMap::new()));
    let roster: ActiveConnections = Arc::new(DashMap::new());
    let db: sled::Db = sled::open("./rogued.db").unwrap();
    let hostname: String = gethostname::gethostname().to_string_lossy().to_string();
    let my_uid = device_id.clone();

    let properties = [
        ("not_even_closee", "baby"),
        ("technoblade", "never_dies!!!!"),
        ("deviceId", &device_id),
    ];

    let ip: String = match local_ip_address::local_ip() {
        Ok(ip) => ip.to_string(),
        Err(e) => {
            error!("Error when getting local IP address: \r\n{e}");
            return Ok(());
        }
    };

    let sinfo = ServiceInfo::new(
        MDNS_SERVICE_TYPE,
        &hostname,
        &format!("{hostname}.local."),
        ip,
        TCP_PORT,
        &properties[..],
    )
    .unwrap();

    let fullname = sinfo.get_fullname().to_string();

    match std::fs::remove_file(SOCKET_BIND_PATH) {
        Ok(()) => {
            info!("Discarding existing socket files");
        }
        Err(e) => {
            if e.kind() == ErrorKind::NotFound {
                info!("No existing socket files found");
            } else {
                error!("Owned by skill issue, \r\nError: {}", e);
            }
        }
    }

    let mdns = ServiceDaemon::new().expect("Problem when starting mDNS daemon");
    mdns.register(sinfo)
        .expect("mDNS: Failed to register our service");

    let de_receiver = mdns.monitor().expect("Failed to monitor mDNS daemon");
    std::thread::spawn(move || {
        while let Ok(event) = de_receiver.recv() {
            match event {
                mdns_sd::DaemonEvent::Error(error) => {
                    error!("mDNS daemon error: \r\n{:?}", error);
                }
                _ => {}
            };
        }
    });

    tokio::spawn(tcp_server_loop(
        TCP_PORT,
        my_uid.clone(),
        db.clone(),
        roster.clone(),
    ));

    let peers_clone = Arc::clone(&peers);
    tokio::spawn(async move {
        task_dispatcher(peers_clone, roster, db, my_uid)
            .await
            .expect("Owned by skill issue,\r\nError with the unix sockets function");
    });

    discover_hosts(&mdns, peers, fullname.clone()).await?;

    tokio::signal::ctrl_c().await?;
    let _ = mdns.unregister(&fullname);
    mdns.shutdown().unwrap();

    match std::fs::remove_file(SOCKET_BIND_PATH) {
        Ok(()) => info!("Removed socket file"),
        Err(e) if e.kind() == ErrorKind::NotFound => {}
        Err(e) => error!("Failed to remove socket file: {}", e),
    }

    Ok(())
}
