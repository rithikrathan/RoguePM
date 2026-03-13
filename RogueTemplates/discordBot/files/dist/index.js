"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const discord_js_1 = require("discord.js");
const ping_1 = require("./commands/ping");
const help_1 = require("./commands/help");
const onMention_1 = require("./events/onMention");
let configs = require('../config/config.json');
// let logs = require('../lang/logs.json')
const client = new discord_js_1.Client({
    intents: configs.client.intents
});
client.on('ready', (c) => {
    console.log(`${c.user.username} \ is online.`);
});
client.on(discord_js_1.Events.MessageCreate, (message) => {
    if (message.author.bot)
        return;
    // if (message.mentions.has(client.user!)) {
    // 	message.reply("hello how are you?")
    // }
    (0, onMention_1.default)(client, message);
    (0, ping_1.default)(client, message);
    (0, help_1.default)(client, message);
});
client.login(configs.client.token);
