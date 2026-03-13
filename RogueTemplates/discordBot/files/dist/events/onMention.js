"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = onMention;
function onMention(client, message) {
    if (message.mentions.has(client.user) && !message.author.bot) {
        message.reply("Hey! Need help? Type '!help'");
        console.log(`User ${message.author.username} mentioned this bot`);
    }
}
