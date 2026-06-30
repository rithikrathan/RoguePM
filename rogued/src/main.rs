// INFO:
// -----------------------------------------------------------------------------
// Script: main.rs
// Version: 0.0.1
// Author: RITHIK RATHAN C. <github.com/rithikrathan>
// License:
// Repository: https://github.com/rithikrathan/RoguePM
// Project: RoguePM
// Created: 2026-06-23
// Description: Very first iteration of the rogued consept of a daemon that handles
//             distributed project management across a LAN using sshfs and some TCP
//             connection, idk  how it turns out
// -----------------------------------------------------------------------------

use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
// use sled::{Db, Tree};
// use tokio::net::{TcpListener, UnixListener};
use std::collections::HashMap;
use std::io::ErrorKind;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;
use tokio::sync::Mutex; // for serializations
use tracing::{Level, error, info}; // from unix socket // for sled database

// mod connections;
mod types;
use types::{PeerInfo, Response, USRequest};

static SOCKET_BIND_PATH: &str = "/tmp/rogued.sock";
static MDNS_SERVICE_TYPE: &str = "_rogued._tcp.local.";
static INCLUDE_SELF: bool = true; // include self host name
static TCP_PORT: u16 = 5200;
// static DATABASE_PATH: &str = "~/.rogued/Data/"; // place where the sled database is stored

// =-=-=-=-=-=-=-= [ HELPER FUNCTIONS ] =-=-=-=-=-=-=-=

// UNIXSOCKETS are the way our rogue script interacts witht the daemon, to handle tcp connections and
// exchange project list, This connection is between the daemon and the rogue script, that happens
// locally via a shared file
// async fn handle_unix_sockets(peers: &Arc<Mutex<HashMap<String, String>>>) -> std::io::Result<()> {
async fn task_dispatcher(peers: Arc<Mutex<HashMap<String, PeerInfo>>>) -> std::io::Result<()> {
    // bind a listener to that socket file and handle the errors
    let listener = match UnixListener::bind(SOCKET_BIND_PATH) {
        Ok(l) => l,
        Err(e) => {
            error!("Owned by skill issue, \r\nError: {}", e);
            return Err(e);
        }
    };

    // loop that handles the socket connections
    loop {
        // use the listener to accept incomming connections
        match listener.accept().await {
            Ok((mut stream, _addr)) => {
                let peers = Arc::clone(&peers);
                tokio::spawn(async move {
                    info!("Unix Socket connected");
                    // crete a mutable data buffer to store the incomming message
                    //spawn a process here for concurrency
                    let mut input_data = Vec::new();
                    // read till EOF into that buffer
                    if let Err(e) = stream.read_to_end(&mut input_data).await {
                        //handle error
                        error!(
                            "While reading the input stream from the socket connection: \r\n{e}"
                        );
                    }
                    // handle errors later
                    let serialized_request: USRequest = match serde_json::from_slice(&input_data) {
                        Ok(ser) => ser,
                        Err(e) => {
                            error!("Error while Deserialization: \r\n {}", e);
                            return;
                        }
                    }; // parse JSON

                    // process requests here
                    match serialized_request.request_type.as_str() {
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
                            // dumps the discovered hosts from mDNS to the frontend
                            info!("{:?}", serialized_request);
                            let locked = peers.lock().await;
                            let serialized_response = match serde_json::to_string(&*locked) {
                                Ok(ser) => ser,
                                Err(e) => {
                                    error!("Error while Serialization: \r\n {}", e);
                                    return;
                                }
                            };
                            // info!("{:#?}", &*locked);
                            if let Err(e) = stream.write_all(serialized_response.as_bytes()).await {
                                error!(
                                    "While writing to the output stream of the socket connection: \r\n{e}"
                                );
                            }
                        }

                        // pairing is done by the uid and not the hostname
                        "pair_request" => {
                            // request a host for connection
                            info!("{:?}", serialized_request);
                        }

                        "pair_reject" => {
                            // reject a host request
                            info!("{:?}", serialized_request);
                        }

                        "pair_accept" => {
                            // accept a host request
                            info!("{:?}", serialized_request);
                        }

                        "list_pending" => {
                            // list pending requests
                            info!("{:?}", serialized_request);
                        }

                        "list_paired" => {
                            // list paired hosts
                            info!("{:?}", serialized_request);
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

// async fn pair(peers: Arc<Mutex<HashMap<String, String>>>, fullname: String) {}

async fn discover_hosts(
    mdns: &ServiceDaemon,
    peers: Arc<Mutex<HashMap<String, PeerInfo>>>,
    self_fullname: String,
) -> std::io::Result<()> {
    let mdns_receiver = mdns.browse(MDNS_SERVICE_TYPE).unwrap();
    std::thread::spawn(move || {
        while let Ok(event) = mdns_receiver.recv() {
            match event {
                // log and handle if peer is discovered
                ServiceEvent::ServiceResolved(serv_resolved) => {
                    info!("Service resolved: {}", serv_resolved.get_hostname());

                    let ip_str = serv_resolved
                        .get_addresses_v4()
                        .iter()
                        .map(|ip| ip.to_string())
                        .collect::<Vec<_>>()
                        .join(", ");

                    // let uid = serv_resolved.get_fullname().to_string();
                    // let uid = serv_resolved.get_property("deviceId").unwrap_or("unknown");
                    let uid = serv_resolved
                        .get_property("deviceId")
                        .map(|s| s.val_str())
                        .unwrap_or("unknown");
                    // skip our own service
                    if serv_resolved.get_fullname().to_string() == *self_fullname && !INCLUDE_SELF {
                        continue;
                    }
                    // add to discovered peers list
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

                // log if peer is being shutdown
                ServiceEvent::ServiceRemoved(_, fullname) => {
                    // remove from discovered peers list (more like only keep the things that are
                    // not the removed one)
                    info!("Service removed: {}", fullname);
                    peers
                        .blocking_lock()
                        .retain(|_, info| info.fullname != fullname);
                }

                // log if self is being shutdown
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

// =-=-=-=-=-=-=-= [ MAIN FUNCTION ] =-=-=-=-=-=-=-=

#[tokio::main]
async fn main() -> std::io::Result<()> {
    println!("Hello Idiots!"); // mandatory insult

    // first time using async rust btw
    tracing_subscriber::fmt().with_max_level(Level::INFO).init(); // To display logs on the standard IO

    let device_id = std::fs::read_to_string("/etc/machine-id")
        .map(|s| s.trim().to_string())
        .expect("/etc/machine-id not found");

    // =-=-=-=-=-=-=-= [ DEFINITIONS ] =-=-=-=-=-=-=-=

    // hashmap of hostname => ipaddress string
    let peers: Arc<Mutex<HashMap<String, PeerInfo>>> = Arc::new(Mutex::new(HashMap::new()));
    let hostname: String = gethostname::gethostname().to_string_lossy().to_string();

    // dummmy property
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

    //service info struct that will be exchanged
    let sinfo = ServiceInfo::new(
        MDNS_SERVICE_TYPE,             // service type
        &hostname,                     // instance name
        &format!("{hostname}.local."), // host name in the context of a DNS
        ip,                            // local IP address
        TCP_PORT,                      // port it runs on
        &properties[..], // dummmy properties, ATP I just turned off my brain for thinking and use quick
                         // patch up solutions
    )
    .unwrap();

    let fullname = sinfo.get_fullname().to_string();

    // =-=-=-=-=-=-=-= [ PROCESS ] =-=-=-=-=-=-=-=

    // Init sled database
    // let database: Db = sled::open(DATABASE_PATH).unwrap();
    // let paired: Tree = database.open_tree("pairedDevices").unwrap(); //  stores paired devices

    // remove old Socket Files if it exists
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

    // create an mdns daemon object to run in a separate thread
    let mdns = ServiceDaemon::new().expect("Problem when starting mDNS daemon");
    mdns.register(sinfo)
        .expect("mDNS: Failed to register our service");
    // handle mDNS daemon errors
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

    //concurrently handle unix sockets
    let peers_clone = Arc::clone(&peers); // clone to use this in async below
    tokio::spawn(async move {
        task_dispatcher(peers_clone)
            .await
            .expect("Owned by skill issue,\r\nError with the unix sockets function");
    }); // concurrently run unix sockets?? ig so

    discover_hosts(&mdns, peers, fullname.clone()).await?; // handle mDNS based host discovery
    // it takes a while and its inconsistent, i mean some times its fast and sometimes not

    // =-=-=-=-=-=-=-= [ CLEANUP ] =-=-=-=-=-=-=-=

    tokio::signal::ctrl_c().await?;
    let _ = mdns.unregister(&fullname); // unnecessary but meh whatever
    mdns.shutdown().unwrap(); // shutdown already unregisters

    match std::fs::remove_file(SOCKET_BIND_PATH) {
        //cleanup socket files
        Ok(()) => info!("Removed socket file"),
        Err(e) if e.kind() == ErrorKind::NotFound => {}
        Err(e) => error!("Failed to remove socket file: {}", e),
    }

    Ok(())
}
