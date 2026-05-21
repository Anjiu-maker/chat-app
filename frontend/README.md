# Chat Frontend

Flutter client for the chat app.

## Run locally

After installing Flutter SDK:

```bash
flutter create .
flutter pub get
flutter run --dart-define=SOCKET_URL=http://10.0.2.2:3000
```

Use `http://127.0.0.1:3000` for desktop/web builds and `http://10.0.2.2:3000` for Android emulator.


通过脚本启用的关闭方法，在powershell 中运行
(Get-NetTCPConnection -LocalPort 5174 -State Listen).OwningProcess
Stop-Process -Id $pid -Force