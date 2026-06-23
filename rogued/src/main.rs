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
use tokio::net::UnixListener;
use tracing::{error, info}; // from unix socket

// use serde::{Deserialize, Serialize};
// use std::error::Error; //for errors
// use tokio::io::{AsyncReadExt, AsyncWriteExt}; // read and write from stream

static SOCKET_BIND_PATH: &str = "/tmp/rogued.sock";

// =-=-=-=-=-=-=-= [ HELPER FUNCTIONS ] =-=-=-=-=-=-=-=
async fn handle_unix_sockets() -> std::io::Result<()> {
    let _listener = match UnixListener::bind(SOCKET_BIND_PATH) {
        Ok(l) => l,
        Err(e) => {
            error!("Owned by skill issue, \r\nError: {}", e);
            return Ok(());
        }
    };
    Ok(())
}

// =-=-=-=-=-=-=-= [ MAIN FUNCTION ] =-=-=-=-=-=-=-=
#[tokio::main]
async fn main() -> std::io::Result<()> {
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
