# Architecture

## Backend

NestJS owns WebSocket connections through `ChatGateway`. Clients join a room with `room:join`, receive recent MySQL-backed history through `room:history`, then send messages through `message:send`.

Current modules:

- `ChatModule`: room events and message persistence.
- `RedisModule`: online socket tracking.
- `StorageModule`: S3-compatible upload service for MinIO or cloud OSS adapters.

## Data Flow

1. Flutter connects to the NestJS Socket.IO endpoint.
2. Client emits `room:join` with a room id.
3. Backend returns recent messages from MySQL.
4. Client emits `message:send`.
5. Backend validates, stores, and broadcasts the message to the room.

## Next Milestones

- Add user authentication and JWT socket guards.
- Add conversations, members, read receipts, and message delivery state.
- Add file upload REST endpoint and file-message event shape.
- Add Redis Socket.IO adapter for multi-instance scaling.
