import http from "http";
import express from "express";
import { WebSocketServer } from "ws";
import crypto from "crypto";

const PORT = process.env.PORT ? Number(process.env.PORT) : 8080;
const AUTH_TOKEN = process.env.USAGE_AUTH_TOKEN;
const HEARTBEAT_TTL_MS = process.env.HEARTBEAT_TTL_MS
  ? Number(process.env.HEARTBEAT_TTL_MS)
  : 90_000;
const BROADCAST_INTERVAL_MS = process.env.BROADCAST_INTERVAL_MS
  ? Number(process.env.BROADCAST_INTERVAL_MS)
  : 5_000;

const app = express();
app.get("/healthz", (_req, res) => {
  res.status(200).json({ ok: true, ts: Date.now() });
});

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: "/usage" });

const installs = new Map(); // deviceId -> { lastSeen, socketIds: Set<string> }
const sockets = new Map(); // socketId -> { ws, deviceId? }

function now() {
  return Date.now();
}

function isAuthorized(req, messageToken) {
  if (!AUTH_TOKEN) {
    return true; // no auth configured
  }
  const header = req.headers["authorization"] || "";
  const bearer = typeof header === "string" ? header.replace(/^Bearer\s+/i, "") : "";
  const urlToken = new URL(req.url, `http://${req.headers.host}`).searchParams.get("token");
  const token = messageToken || urlToken || bearer;
  return token === AUTH_TOKEN;
}

function pruneExpired() {
  const cutoff = now() - HEARTBEAT_TTL_MS;
  for (const [deviceId, record] of installs.entries()) {
    if (record.lastSeen < cutoff) {
      installs.delete(deviceId);
    }
  }
}

function activeCount() {
  pruneExpired();
  return installs.size;
}

function broadcastCount() {
  const count = activeCount();
  const payload = JSON.stringify({ activeUsers: count, ts: now() });
  for (const { ws } of sockets.values()) {
    if (ws.readyState === ws.OPEN) {
      ws.send(payload);
    }
  }
}

function attachInstall(deviceId, socketId) {
  const existing = installs.get(deviceId) || { lastSeen: 0, socketIds: new Set() };
  existing.lastSeen = now();
  existing.socketIds.add(socketId);
  installs.set(deviceId, existing);
}

function detachSocket(socketId) {
  const entry = sockets.get(socketId);
  sockets.delete(socketId);
  if (!entry || !entry.deviceId) {
    return;
  }
  const record = installs.get(entry.deviceId);
  if (!record) {
    return;
  }
  record.socketIds.delete(socketId);
  if (record.socketIds.size === 0) {
    // keep lastSeen; TTL pruning handles expiration
    installs.set(entry.deviceId, record);
  }
}

wss.on("connection", (ws, req) => {
  const socketId = crypto.randomUUID();
  sockets.set(socketId, { ws });

  if (!isAuthorized(req)) {
    ws.close(1008, "unauthorized");
    sockets.delete(socketId);
    return;
  }

  ws.send(JSON.stringify({ activeUsers: activeCount(), ts: now() }));

  ws.on("message", (data) => {
    let message;
    try {
      message = JSON.parse(data.toString());
    } catch {
      return;
    }

    if (!isAuthorized(req, message?.token)) {
      ws.close(1008, "unauthorized");
      detachSocket(socketId);
      return;
    }

    if (message?.type === "heartbeat" && typeof message.deviceId === "string") {
      sockets.set(socketId, { ws, deviceId: message.deviceId });
      attachInstall(message.deviceId, socketId);
    }
  });

  ws.on("close", () => {
    detachSocket(socketId);
  });
});

setInterval(broadcastCount, BROADCAST_INTERVAL_MS);

server.listen(PORT, () => {
  console.log(`usage-ws listening on :${PORT}`);
});
