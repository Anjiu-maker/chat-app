import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chat_frontend/main.dart';

void main() {
  testWidgets('shows login screen and switches to register', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ChatApp());

    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('验证码登录'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);

    await tester.tap(find.text('注册账号'));
    await tester.pumpAndSettle();

    expect(find.text('注册'), findsOneWidget);
    expect(find.text('请输入昵称'), findsOneWidget);
  });
}
