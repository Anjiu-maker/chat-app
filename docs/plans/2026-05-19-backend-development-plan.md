# Backend Development Implementation Plan

**Goal:** Build the NestJS backend for the chat app with authentication, users, contacts, conversations, groups, messages, realtime Socket.IO, Redis presence, and MinIO/S3-compatible file support.

**Architecture:** Use feature modules around business domains: `auth`, `users`, `contacts`, `conversations`, `groups`, `messages`, `files`, `realtime`, `redis`, and `storage`. MySQL stores durable domain data through TypeORM entities; Redis stores short-lived presence, socket mappings, OTP codes, and counters; Socket.IO broadcasts realtime events after service-layer validation.

**Tech Stack:** NestJS, TypeORM, MySQL, Redis/ioredis, Socket.IO, JWT, bcrypt/argon2, class-validator, MinIO/S3 SDK.

---

## Guiding Principles

- Keep REST APIs and Socket.IO events aligned with the Flutter screens already built.
- Avoid putting business logic inside gateways or controllers; keep it in services.
- Use JWT for HTTP and Socket.IO authentication.
- Use TypeORM migrations for production-like schema evolution; keep `synchronize=true` only for early local development.
- Keep file storage S3-compatible so MinIO and OSS can share one abstraction.
- Add focused tests around validation, services, and auth guards before broad integration tests.

## Phase 0: Backend Baseline

**Files:**
- Modify: `backend/package.json`
- Modify: `backend/.env.example`
- Modify: `backend/src/app.module.ts`
- Create: `backend/src/common/*`

**Tasks:**

1. Confirm Node version baseline and package install.
2. Add backend dependencies:
   - `@nestjs/jwt`
   - `@nestjs/passport`
   - `passport`
   - `passport-jwt`
   - `bcryptjs` or `argon2`
   - `multer`
   - `@types/multer`
3. Add common response and pagination helpers:
   - `PageQueryDto`
   - `PageResult<T>`
   - `CurrentUser` decorator
   - `JwtAuthGuard`
   - `SocketAuthGuard`
4. Add global exception/error-shape policy only if needed; keep it simple first.
5. Verification:
   - `npm install`
   - `npm run build`

## Phase 1: Database Model

**Entities to create:**

- `User`
  - `id`
  - `phone`
  - `nickname`
  - `avatarUrl`
  - `passwordHash`
  - `bio`
  - `status`
  - `createdAt`
  - `updatedAt`

- `Contact`
  - `id`
  - `ownerId`
  - `contactUserId`
  - `remark`
  - `tags`
  - `createdAt`

- `Conversation`
  - `id`
  - `type`: `direct` or `group`
  - `title`
  - `avatarUrl`
  - `lastMessageId`
  - `lastMessagePreview`
  - `lastMessageAt`
  - `createdAt`
  - `updatedAt`

- `ConversationMember`
  - `id`
  - `conversationId`
  - `userId`
  - `role`
  - `muted`
  - `pinned`
  - `savedToContacts`
  - `lastReadMessageId`
  - `joinedAt`

- `GroupProfile`
  - `id`
  - `conversationId`
  - `groupNo`
  - `announcement`
  - `ownerId`
  - `createdAt`

- `Message`
  - Expand existing entity:
  - `conversationId`
  - `senderId`
  - `type`: `text`, `image`, `file`, `system`, `task`
  - `content`
  - `payload`
  - `status`
  - `createdAt`

- `FileObject`
  - `id`
  - `ownerId`
  - `bucket`
  - `objectKey`
  - `fileName`
  - `mimeType`
  - `size`
  - `url`
  - `createdAt`

**Indexes:**

- unique `User.phone`
- unique `Contact(ownerId, contactUserId)`
- index `ConversationMember(userId, conversationId)`
- index `Message(conversationId, createdAt)`
- index `FileObject(ownerId, createdAt)`

**Verification:**

- `npm run build`
- Start MySQL with `docker compose up -d mysql`
- Run local schema sync or migrations.

## Phase 2: Auth Module

**REST APIs:**

- `POST /auth/send-code`
  - body: `{ phone: string, scene: "login" | "register" }`
  - local dev can return or log the code
  - Redis stores OTP with TTL

- `POST /auth/register`
  - body: `{ phone, code, nickname, password }`
  - creates user
  - returns `{ accessToken, user }`

- `POST /auth/login`
  - body: `{ phone, password }`
  - returns `{ accessToken, user }`

- `POST /auth/login-code`
  - body: `{ phone, code }`
  - returns `{ accessToken, user }`

- `GET /auth/me`
  - returns current user

**Implementation notes:**

- Store OTP in Redis key: `otp:{scene}:{phone}`.
- Hash password using `bcryptjs` or `argon2`.
- JWT payload: `{ sub: userId, phone }`.
- Add DTO validation for phone, code, password length.

**Tests:**

- register fails with invalid code
- register creates user with valid code
- password login rejects wrong password
- `GET /auth/me` requires token

## Phase 3: Users And Contacts

**REST APIs:**

- `GET /users/me`
- `PATCH /users/me`
- `GET /users/search?keyword=`
- `GET /contacts`
- `POST /contacts`
- `PATCH /contacts/:id`
- `DELETE /contacts/:id`

**Frontend mapping:**

- Contacts page consumes `GET /contacts`.
- Contact detail consumes `GET /users/:id` or embedded contact data.
- Search page consumes `GET /users/search`.

**Implementation notes:**

- Prevent adding self as contact.
- Prevent duplicate contacts.
- Support remark and tags as optional fields.

## Phase 4: Conversations

**REST APIs:**

- `GET /conversations`
  - returns message home list
  - includes unread count, last message, pinned/muted flags

- `GET /conversations/:id`
  - returns detail, members, settings for current user

- `POST /conversations/direct`
  - body: `{ userId }`
  - creates or returns direct conversation

- `PATCH /conversations/:id/settings`
  - body: `{ muted?, pinned?, savedToContacts? }`

- `POST /conversations/:id/read`
  - body: `{ messageId }`

**Implementation notes:**

- Conversation list should sort pinned first, then latest activity.
- Direct conversations should be unique per pair.
- Unread count can be computed initially, then optimized later.

## Phase 5: Groups

**REST APIs:**

- `GET /groups`
  - supports tabs: created, joined, active

- `POST /groups`
  - body: `{ name, memberIds, announcement?, muted?, savedToContacts? }`
  - creates conversation + group profile + members

- `GET /groups/:conversationId`
  - group detail page

- `PATCH /groups/:conversationId`
  - update name, avatar, announcement

- `POST /groups/:conversationId/members`
  - invite members

- `DELETE /groups/:conversationId/members/:userId`
  - remove member

- `POST /groups/:conversationId/leave`

**Implementation notes:**

- Creator becomes owner.
- Member roles: `owner`, `admin`, `member`.
- Generate human-readable `groupNo`.
- Add system message when members join or leave.

## Phase 6: Messages

**REST APIs:**

- `GET /conversations/:id/messages?cursor=&limit=`
- `POST /conversations/:id/messages`
  - useful fallback for non-socket sending

**Socket.IO events:**

- Client emits `conversation:join`
  - `{ conversationId }`

- Server emits `conversation:history`
  - recent messages

- Client emits `message:send`
  - `{ conversationId, type, content, payload?, clientMessageId }`

- Server emits `message:new`
  - persisted message

- Server emits `message:ack`
  - `{ clientMessageId, message }`

- Server emits `message:error`
  - `{ clientMessageId, reason }`

- Client emits `message:read`
  - `{ conversationId, messageId }`

**Implementation notes:**

- Check sender is conversation member before accepting message.
- Store message first, update conversation last message, then broadcast.
- Keep `clientMessageId` so Flutter can reconcile optimistic messages.

## Phase 7: Realtime Presence And Scaling

**Redis keys:**

- `socket:user:{userId}` set of socket ids
- `presence:online_users` set of user ids
- optional `conversation:online:{conversationId}` set of user ids

**Socket lifecycle:**

- Authenticate socket via JWT in handshake.
- On connect:
  - map socket to user
  - mark user online
  - emit presence update

- On disconnect:
  - remove socket
  - mark user offline only when no sockets remain

**Later scaling:**

- Add `@socket.io/redis-adapter` when running multiple backend instances.

## Phase 8: Files

**REST APIs:**

- `POST /files/upload`
  - multipart file upload
  - stores in MinIO or OSS-compatible storage
  - returns `FileObject`

- `GET /files/:id`
  - metadata

- `GET /files/:id/download-url`
  - later can return presigned URL

**Message integration:**

- File message payload:

```json
{
  "fileId": "uuid",
  "fileName": "竞品分析报告.docx",
  "mimeType": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "size": 2516582,
  "url": "..."
}
```

**Implementation notes:**

- Validate max file size.
- Validate MIME allowlist for first version.
- Use object key: `users/{userId}/{yyyy}/{mm}/{uuid}-{safeName}`.

## Phase 9: API Contract For Flutter

Create `docs/api/backend-contract.md` with:

- Auth request/response examples
- User shape
- Conversation list shape
- Group detail shape
- Message shape
- File upload shape
- Socket.IO event list
- Error shape

This keeps Flutter integration predictable.

## Phase 10: Testing Strategy

**Unit tests:**

- Auth service
- Conversation service
- Group service
- Message service
- File service key generation

**Integration tests:**

- Register and login flow
- Create group flow
- Send message flow
- Upload file metadata flow

**Manual local verification:**

1. `docker compose up -d mysql redis minio minio-init`
2. `cd backend`
3. `copy .env.example .env`
4. `npm run start:dev`
5. Use REST client/Postman/curl to register, login, create group, send message.
6. Use Socket.IO client to test join/send/receive.

## Recommended Implementation Order

1. Common module and dependency setup.
2. Database entities and schema.
3. Auth with JWT and Redis OTP.
4. Users and contacts.
5. Conversations.
6. Groups.
7. Messages REST and Socket.IO.
8. Presence.
9. File upload.
10. API contract docs.
11. Tests and cleanup.

## Acceptance Criteria

- Backend builds with `npm run build`.
- Auth can register and login a user.
- JWT protects REST and Socket.IO.
- User can create a group and list groups.
- User can list conversations.
- User can join a socket conversation and send/receive messages.
- User can upload a file and send it as a message payload.
- MySQL stores durable data.
- Redis stores OTP and presence data.
- MinIO stores uploaded files.
- Flutter has stable API and socket contracts to integrate against.
