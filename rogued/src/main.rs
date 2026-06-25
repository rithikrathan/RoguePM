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

use core::result::Result::Ok;
use local_ip_address;
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo}; // for mDNS based host discovery
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::ErrorKind;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixListener;
use tokio::sync::Mutex; // for serializations
use tracing::{Level, error, info, trace}; // from unix socket

static SOCKET_BIND_PATH: &str = "/tmp/rogued.sock";
static MDNS_SERVICE_TYPE: &str = "_rogued._tcp.local.";

// =-=-=-=-=-=-=-= [ STRUCTS ] =-=-=-=-=-=-=-=

#[derive(Deserialize, Debug)]
struct USRequest {
    request_type: String,
}

#[derive(Serialize, Debug)]
struct Response {
    res: String,
}

// =-=-=-=-=-=-=-= [ HELPER FUNCTIONS ] =-=-=-=-=-=-=-=

// UNIXSOCKETS are the way our rogue script interacts witht he daemon, to handle tcp connections and
// exchange project list, This connection is between the daemon and the rogue script, that happens
// locally via a shared file
// async fn handle_unix_sockets(peers: &Arc<Mutex<HashMap<String, String>>>) -> std::io::Result<()> {
async fn handle_unix_sockets(peers: Arc<Mutex<HashMap<String, String>>>) -> std::io::Result<()> {
    // bind a listener to that socket file and handle the errors
    let listener = match UnixListener::bind(SOCKET_BIND_PATH) {
        Ok(l) => l,
        Err(e) => {
            error!("Owned by skill issue, \r\nError: {}", e);
            return Ok(());
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
                    let serialised_request: USRequest = match serde_json::from_slice(&input_data) {
                        Ok(ser) => ser,
                        Err(e) => {
                            error!("Error while Deserialization: \r\n {}", e);
                            return;
                        }
                    }; // parse JSON

                    // process requests here
                    if serialised_request.request_type == "ping" {
                        println!("{:?}", serialised_request);
                        let response = Response {
                            res: "Pong!".to_string(),
                        };

                        // crete a mutable data buffer to store the response message and serialize
                        let mut serialized_response = match serde_json::to_vec(&response) {
                            Ok(ser) => ser,
                            Err(e) => {
                                error!("Error while Serialization: \r\n {}", e);
                                return;
                            }
                        };

                        if let Err(e) = stream.write_all(&mut serialized_response).await {
                            //handle error
                            error!(
                                "While writing to the output stream of the socket connection: \r\n{e}"
                            );
                        }
                    } else if serialised_request.request_type == "discoverHost" {
                        // handle it here later
                        println!("{:?}", serialised_request);
                        let locked = peers.lock().await;
                        println!("peers: \r\n{:#?}", *locked);
                        return;
                    } else {
                        // Anything other than the above types of request
                        println!("Something phishy... \r\n{:#?}", serialised_request);
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
    peers: Arc<Mutex<HashMap<String, String>>>,
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

                    peers
                        .blocking_lock()
                        .insert(serv_resolved.get_hostname().to_string(), ip_str);
                }

                other_event => {
                    trace!("Other event: \r\n{:?}", other_event);
                }
            }
        }
        println!("{:?}", peers);
    });
    Ok(())
}

// =-=-=-=-=-=-=-= [ MAIN FUNCTION ] =-=-=-=-=-=-=-=

#[tokio::main]
async fn main() -> std::io::Result<()> {
    println!("Hello Idiots!"); // mandatory insult

    // dummmy property
    let properties = [
        ("not_even_closee", "baby"),
        ("technoblade", "never_dies!!!!"),
    ];

    // some variables
    let hostname: String = gethostname::gethostname().to_string_lossy().to_string();

    let ip: String = match local_ip_address::local_ip() {
        Ok(ip) => ip.to_string(),
        Err(e) => {
            error!("Error when getting local IP address: \r\n{e}");
            return Ok(());
        }
    };
    // hashmap of hostname => ipaddress string
    let peers: Arc<Mutex<HashMap<String, String>>> = Arc::new(Mutex::new(HashMap::new()));

    // To display logs on the standard IO
    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

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

    //service info struct that will be exchanged
    let sinfo = ServiceInfo::new(
        MDNS_SERVICE_TYPE,             // service type
        &hostname,                     // instance name
        &format!("{hostname}.local."), // host nanme in the context of a DNS
        ip,                            // local IP address
        5200,                          // port it runs on
        &properties[..], // dummmy properties, ATP I just turned off my brain for thinking and use quick
                         // patch up solutions
    )
    .unwrap();

    mdns.register(sinfo)
        .expect("mDNS: Failed to register our service");

    let peers_clone = Arc::clone(&peers);
    tokio::spawn(async move {
        handle_unix_sockets(peers_clone)
            .await
            .expect("Owned by skill issue,\r\nError with the unix sockets function");
    }); // concurrently run unix sockets?? ig so

    // first time using async rust btw
    discover_hosts(&mdns, peers).await?;

    tokio::signal::ctrl_c().await?;

    Ok(())
}
