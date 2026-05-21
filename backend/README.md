# Chat Backend

NestJS backend with Socket.IO, MySQL, Redis, and S3-compatible file storage.

## Run locally

Node.js 20+ is the project baseline. The local workspace currently targets Node 24.

```bash
cp .env.example .env
npm install
npm run start:dev
```

## REST API

All protected APIs use `Authorization: Bearer <accessToken>`.

Auth:

- `POST /auth/send-code` `{ "phone": "13800138000", "scene": "register" | "login" }`
- `POST /auth/register` `{ "phone": "...", "code": "123456", "nickname": "李想", "password": "password123" }`
- `POST /auth/login` `{ "phone": "...", "password": "password123" }`
- `POST /auth/login/code` `{ "phone": "...", "code": "123456" }`

Users and contacts:

- `GET /users/me`
- `PATCH /users/me`
- `GET /users/search?q=张`
- `GET /contacts`
- `POST /contacts`
- `PATCH /contacts/:id`
- `DELETE /contacts/:id`

Conversations and groups:

- `GET /conversations`
- `GET /conversations/:id`
- `POST /conversations/direct`
- `PATCH /conversations/:id/settings`
- `POST /conversations/:id/read`
- `GET /groups`
- `POST /groups`

Files:

- `POST /files/upload` multipart form field: `file`

## Socket.IO

Connect with the same JWT:

```js
io("http://localhost:3000", {
  auth: { token: accessToken },
});
```

Events:

- `conversation:join` with `{ "conversationId": "uuid" }`
- `conversation:leave` with `{ "conversationId": "uuid" }`
- `message:send` with `{ "conversationId": "uuid", "content": "Hi", "type": "text" }`
- `message:read` with `{ "conversationId": "uuid" }`
- server emits `conversation:history`, `message:new`, `conversation:user_joined`, `conversation:user_left`, and `message:read`

Development note: non-production `POST /auth/send-code` returns `devCode` so the Flutter UI can be wired before a real SMS provider is added.
