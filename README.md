# Chat App

Chat app workspace with:

- Frontend: Flutter
- Backend: NestJS + Socket.IO
- Database: MySQL
- Cache: Redis
- File storage: MinIO/S3-compatible storage

## Structure

```text
chat-app/
  backend/   NestJS API and Socket.IO gateway
  frontend/  Flutter client source
  docs/      Architecture notes
```

## Start infrastructure

```bash
docker compose up -d
```

MinIO console: `http://127.0.0.1:9001`

## Start backend

Node.js 20 LTS is the project baseline.

```bash
cd backend
copy .env.example .env
npm install
npm run start:dev
```

## Start frontend

Flutter SDK is required. After installing Flutter:

```bash
cd frontend
flutter create .
flutter pub get
flutter run --dart-define=SOCKET_URL=http://10.0.2.2:3000
```

For desktop/web builds, use `--dart-define=SOCKET_URL=http://127.0.0.1:3000`.
