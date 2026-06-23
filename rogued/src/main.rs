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
// use serde::{Deserialize, Serialize};
// use std::error::Error; //for errors
// use tokio::io::{AsyncReadExt, AsyncWriteExt}; // read and write from stream
// use tokio::new::{UnixListener, UnixStream}; // from unix socket

static SOCKET_PATH: &str = "/tmp/rogued.sock";

fn main() {
    println!("Hello Idiots!");
    match std::fs::remove_file(SOCKET_PATH) {
        Ok(()) => {
            println!("Discarding existing socket files");
        }

        Err(e) => {
            if e.kind() == ErrorKind::NotFound {
                println!("No existing socket files found");
            } else {
                println!("Owned by skill issue, \r\nError: {}", e);
            }
        }
    }
}
