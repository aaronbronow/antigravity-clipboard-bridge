import { WebSocket } from 'ws';
import os from 'node:os';
import { execSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';
import { createFrame, parseFrame, loadConfig } from './abc-protocol.js';
// Parse arguments
const args = process.argv.slice(2);
const config = loadConfig();
const brokerUrl = args.find(a => a.startsWith('--broker='))?.split('=')[1] || process.env.ABC_BROKER || config.broker || 'ws://localhost:4224';
const role = (args.find(a => a.startsWith('--role='))?.split('=')[1] || process.env.ABC_ROLE || config.role || 'worker');
const agentId = args.find(a => a.startsWith('--agent-id='))?.split('=')[1] || process.env.ABC_AGENT_ID || config.agentId || `agent-${os.hostname()}-${process.pid}`;
const timeoutMs = parseInt(args.find(a => a.startsWith('--timeout='))?.split('=')[1] || '300000', 10); // 5 mins default
const expectedType = args.find(a => a.startsWith('--type='))?.split('=')[1]; // Optional filter by message_type
const isStream = args.includes('--stream') || args.includes('--persistent');
const logFileArg = args.find(a => a.startsWith('--log-file='))?.slice('--log-file='.length);
const defaultInboxPath = path.join(os.homedir(), '.gemini', 'config', 'plugins', 'abc', 'inbox.jsonl');
const logFilePath = logFileArg || (isStream ? defaultInboxPath : undefined);
function deriveBridgeName() {
    const explicitBridge = args.find(a => a.startsWith('--bridge='))?.split('=')[1] || process.env.ABC_BRIDGE || config.bridge;
    if (explicitBridge) {
        return explicitBridge;
    }
    let repoName = '';
    try {
        const remote = execSync('git config --get remote.origin.url', { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
        if (remote) {
            repoName = path.basename(remote, '.git');
        }
    }
    catch { }
    if (!repoName) {
        repoName = path.basename(process.cwd());
    }
    const user = process.env.USER || os.userInfo().username || 'user';
    return `${repoName}-${user}`;
}
const bridgeName = deriveBridgeName();
let messageReceived = false;
console.log(`[${isStream ? 'Listen Stream' : 'Listen Once'}] Initializing...`);
console.log(`  Agent ID : ${agentId}`);
console.log(`  Bridge   : ${bridgeName}`);
if (logFilePath) {
    console.log(`  Inbox Log: ${logFilePath}`);
}
// Exit guard to prevent hanging forever in one-shot mode (or optional timeout in stream mode)
const timer = !isStream ? setTimeout(() => {
    console.error(`[Listen Once] Timeout reached (${timeoutMs}ms) without receiving a message.`);
    if (ws)
        ws.terminate();
    process.exit(1);
}, timeoutMs) : null;
let ws = null;
function connect() {
    ws = new WebSocket(brokerUrl);
    ws.on('open', () => {
        const handshake = createFrame({ agent_id: agentId, host: os.hostname(), user: os.userInfo().username || 'user', role }, { event: 'handshake', content: bridgeName }, '');
        ws?.send(JSON.stringify(handshake));
    });
    ws.on('message', (data) => {
        try {
            const frame = parseFrame(data.toString());
            const { event, message_type, content, timestamp, uuid } = frame.B;
            // We only care about agent_message events
            if (event === 'agent_message') {
                // If we filtered by type, check if it matches
                if (expectedType && message_type !== expectedType) {
                    return;
                }
                if (logFilePath) {
                    try {
                        fs.mkdirSync(path.dirname(logFilePath), { recursive: true });
                        const record = {
                            uuid,
                            timestamp,
                            from: `${frame.A.agent_id}@${frame.A.host}`,
                            agent_id: frame.A.agent_id,
                            host: frame.A.host,
                            role: frame.A.role,
                            recipient: frame.B.recipient,
                            message_type,
                            content,
                        };
                        fs.appendFileSync(logFilePath, JSON.stringify(record) + '\n', 'utf8');
                    }
                    catch (err) {
                        console.error(`[Log Error] Failed to append to ${logFilePath}: ${err.message}`);
                    }
                }
                console.log(`\n--- MESSAGE RECEIVED ---`);
                console.log(`From: ${frame.A.agent_id}@${frame.A.host}`);
                console.log(`Type: ${message_type}`);
                console.log(`Content:\n${content}`);
                console.log(`------------------------\n`);
                messageReceived = true;
                if (!isStream) {
                    if (timer)
                        clearTimeout(timer);
                    ws?.close();
                    process.exit(0);
                }
            }
            else if (event === 'system_message' && message_type === 'error') {
                console.error(`[System Error] ${content}`);
                if (!isStream) {
                    if (timer)
                        clearTimeout(timer);
                    ws?.close();
                    process.exit(1);
                }
            }
        }
        catch (err) {
            console.error(`[Error] Failed to parse message: ${err.message}`);
        }
    });
    ws.on('close', () => {
        if (isStream) {
            console.warn(`[Disconnected] Connection lost. Reconnecting in 3s...`);
            setTimeout(connect, 3000);
            return;
        }
        if (timer)
            clearTimeout(timer);
        if (!messageReceived) {
            console.warn(`[Disconnected] Connection to the broker was closed before a message was received.`);
            process.exit(1);
        }
        else {
            process.exit(0);
        }
    });
    ws.on('error', (err) => {
        console.error(`[Socket Error] ${err.message}`);
        if (!isStream) {
            if (timer)
                clearTimeout(timer);
            process.exit(1);
        }
    });
}
connect();
