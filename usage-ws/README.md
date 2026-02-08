# Usage WebSocket (Railway)

## Env
- `USAGE_AUTH_TOKEN` (required for auth)
- `PORT` (Railway)
- `HEARTBEAT_TTL_MS` (default 90000)
- `BROADCAST_INTERVAL_MS` (default 5000)

## Protocol
- Connect: `wss://<host>/usage?token=...`
- Heartbeat (client -> server):
```json
{"type":"heartbeat","deviceId":"<stable-install-id>","token":"<optional if sent in query or auth header>"}
```
- Broadcast (server -> client):
```json
{"activeUsers":123,"ts":1730000000000}
```

## Notes
- Unique installs are counted by distinct `deviceId` with a recent heartbeat.
- If `USAGE_AUTH_TOKEN` is set, connections/messages without a valid token are closed.
