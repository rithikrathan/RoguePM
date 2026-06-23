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
use std::io::ErrorKind;
use tokio::io::{_AsyncWriteExt, AsyncReadExt};
use tokio::net::UnixListener;
use tracing::{Level, error, info}; // from unix socket
use tracing_subscriber; // from unix socket // read and write from stream

// use serde::{Deserialize, Serialize};
// use std::error::Error; //for errors

static SOCKET_BIND_PATH: &str = "/tmp/rogued.sock";

// =-=-=-=-=-=-=-= [ HELPER FUNCTIONS ] =-=-=-=-=-=-=-=
async fn handle_unix_sockets() -> std::io::Result<()> {
    // bind a listener to that socket file and handle the errors
    let listener = match UnixListener::bind(SOCKET_BIND_PATH) {
        Ok(l) => l,
        Err(e) => {
            error!("Owned by skill issue, \r\nError: {}", e);
            return Ok(());
        }
    };

    let data = Vec::new();

    // loop that handles the socket connections
    loop {
        // use the listener to accept incomming connections
        match listener.accept().await {
            Ok((stream, _addr)) => {
                info!("Socket connected");
                // crete a mutable data buffer to store the incomming message
                //spawn a process here for concurrency
                let mut data = Vec::new();
                // read till EOF into that buffer
                if let Err(e) = stream.read_to_end(&mut data).await {
                    //handle error
                    error!("While reading the input stream from the socket connection: \r\n{e}");
                }
                // parse the JSON here
                // end the spawned process here
            }
            Err(e) => {
                error!("Error when accepting socket connection, \r\n{}", e);
            }
        }
    }
}

// =-=-=-=-=-=-=-= [ MAIN FUNCTION ] =-=-=-=-=-=-=-=
#[tokio::main]
async fn main() -> std::io::Result<()> {
    // To display logs on the standard IO
    tracing_subscriber::fmt()
        .with_max_level(Level::TRACE)
        .init();

    println!("Hello Idiots!"); // mandatory insult

    // free old Socket Files if it already exists
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

    handle_unix_sockets().await?; // first time using async rust btw

    Ok(())
}
