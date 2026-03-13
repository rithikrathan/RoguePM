"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = help_cmd;
function help_cmd(client, message) {
    if (message.content === '!help') {
        message.reply("Available commands: !ping, !help");
        console.log(`User ${message.author.username} used !help`);
    }
}
