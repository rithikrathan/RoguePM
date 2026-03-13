"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = ping_cmd;
function ping_cmd(client, message) {
    if (message.content === '!ping') {
        message.reply("Pong!");
        console.log(`User ${message.author.username} used !ping`);
    }
}
