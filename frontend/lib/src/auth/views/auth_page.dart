import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_shell.dart';
import '../../services/api_client.dart';

enum _AuthMode { login, register }

enum _LoginMethod { password, code }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _api = ApiClient();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  _LoginMethod _loginMethod = _LoginMethod.password;
  bool _agreed = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _submitting = false;
  int _countdown = 0;
  Timer? _timer;

  bool get _isLogin => _mode == _AuthMode.login;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final pageWidth = width > 520 ? 430.0 : width;

          return ColoredBox(
            color: width > 520 ? const Color(0xFFF4F7FF) : Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: pageWidth),
                child: SizedBox(
                  width: pageWidth,
                  height: constraints.maxHeight,
                  child: ClipRRect(
                    borderRadius: width > 520
                        ? BorderRadius.circular(32)
                        : BorderRadius.zero,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                            child: ColoredBox(color: Colors.white)),
                        const _BrandHeader(),
                        Positioned.fill(
                          top: 262,
                          child: _AuthCard(
                            isLogin: _isLogin,
                            loginMethod: _loginMethod,
                            agreed: _agreed,
                            submitting: _submitting,
                            passwordVisible: _passwordVisible,
                            confirmVisible: _confirmVisible,
                            countdown: _countdown,
                            phoneController: _phoneController,
                            codeController: _codeController,
                            nicknameController: _nicknameController,
                            passwordController: _passwordController,
                            confirmController: _confirmController,
                            onModeChanged: (mode) =>
                                setState(() => _mode = mode),
                            onLoginMethodChanged: (method) {
                              setState(() => _loginMethod = method);
                            },
                            onAgreementChanged: (value) {
                              setState(() => _agreed = value);
                            },
                            onPasswordVisibilityChanged: () {
                              setState(
                                  () => _passwordVisible = !_passwordVisible);
                            },
                            onConfirmVisibilityChanged: () {
                              setState(
                                  () => _confirmVisible = !_confirmVisible);
                            },
                            onSendCode: _sendCode,
                            onSubmit: _submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    try {
      final result = await _api.sendCode(
        phone: phone,
        scene: _isLogin ? 'login' : 'register',
      );
      _startCountdown();
      final devCode = result['devCode'];
      _showMessage(devCode == null ? '验证码已发送' : '开发验证码：$devCode');
    } on ApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      _showMessage('请先阅读并同意用户协议与隐私政策');
      return;
    }

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (phone.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isLogin && _loginMethod == _LoginMethod.password) {
        await _api.login(phone: phone, password: password);
      } else if (_isLogin) {
        await _api.loginByCode(phone: phone, code: _codeController.text.trim());
      } else {
        if (password != _confirmController.text) {
          throw ApiException('两次输入的密码不一致');
        }
        await _api.register(
          phone: phone,
          code: _codeController.text.trim(),
          nickname: _nicknameController.text.trim(),
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
        return;
      }
      if (mounted) setState(() => _countdown--);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderPainter(),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2A7BFF),
                      Color(0xFF1672FF),
                      Color(0xFF65C5FF)
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 58, 24, 0),
              child: Row(
                children: [
                  _AppLogo(),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '畅聊',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '连接朋友与团队，高效畅聊每一天',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  _BubbleArt(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.isLogin,
    required this.loginMethod,
    required this.agreed,
    required this.submitting,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.countdown,
    required this.phoneController,
    required this.codeController,
    required this.nicknameController,
    required this.passwordController,
    required this.confirmController,
    required this.onModeChanged,
    required this.onLoginMethodChanged,
    required this.onAgreementChanged,
    required this.onPasswordVisibilityChanged,
    required this.onConfirmVisibilityChanged,
    required this.onSendCode,
    required this.onSubmit,
  });

  final bool isLogin;
  final _LoginMethod loginMethod;
  final bool agreed;
  final bool submitting;
  final bool passwordVisible;
  final bool confirmVisible;
  final int countdown;
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final TextEditingController nicknameController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final ValueChanged<_AuthMode> onModeChanged;
  final ValueChanged<_LoginMethod> onLoginMethodChanged;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onConfirmVisibilityChanged;
  final VoidCallback onSendCode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
              color: Color(0x160B3C91), blurRadius: 28, offset: Offset(0, -8)),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, isLogin ? 30 : 26, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLogin)
              _LoginTabs(method: loginMethod, onChanged: onLoginMethodChanged)
            else
              const _FormTitle(title: '注册账号'),
            const SizedBox(height: 28),
            _AuthInput(
              controller: phoneController,
              icon: Icons.phone_iphone_rounded,
              hintText: '请输入手机号',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            if (!isLogin || loginMethod == _LoginMethod.code) ...[
              _AuthInput(
                controller: codeController,
                icon: Icons.verified_user_outlined,
                hintText: '请输入验证码',
                keyboardType: TextInputType.number,
                trailing:
                    _CodeButton(countdown: countdown, onPressed: onSendCode),
              ),
              const SizedBox(height: 14),
            ],
            if (!isLogin) ...[
              _AuthInput(
                controller: nicknameController,
                icon: Icons.person_outline_rounded,
                hintText: '请输入昵称',
              ),
              const SizedBox(height: 14),
            ],
            if (!isLogin || loginMethod == _LoginMethod.password) ...[
              _AuthInput(
                controller: passwordController,
                icon: Icons.lock_outline_rounded,
                hintText: '请输入密码',
                obscureText: !passwordVisible,
                trailing: _EyeButton(
                  visible: passwordVisible,
                  onPressed: onPasswordVisibilityChanged,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (!isLogin) ...[
              _AuthInput(
                controller: confirmController,
                icon: Icons.lock_outline_rounded,
                hintText: '请再次输入密码',
                obscureText: !confirmVisible,
                trailing: _EyeButton(
                  visible: confirmVisible,
                  onPressed: onConfirmVisibilityChanged,
                ),
              ),
              const SizedBox(height: 22),
            ] else
              const SizedBox(height: 18),
            _PrimaryButton(
              label: submitting ? '请稍候...' : (isLogin ? '登录' : '注册'),
              onPressed: submitting ? null : onSubmit,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin ? '还没有账号？' : '已有账号？',
                  style:
                      const TextStyle(color: Color(0xFF747C94), fontSize: 15),
                ),
                _InlineAction(
                  label: isLogin ? '注册账号' : '去登录',
                  onTap: () => onModeChanged(
                      isLogin ? _AuthMode.register : _AuthMode.login),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AgreementRow(agreed: agreed, onChanged: onAgreementChanged),
          ],
        ),
      ),
    );
  }
}

class _LoginTabs extends StatelessWidget {
  const _LoginTabs({required this.method, required this.onChanged});

  final _LoginMethod method;
  final ValueChanged<_LoginMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TabButton(
                label: '密码登录',
                active: method == _LoginMethod.password,
                onTap: () => onChanged(_LoginMethod.password),
              ),
            ),
            Expanded(
              child: _TabButton(
                label: '验证码登录',
                active: method == _LoginMethod.code,
                onTap: () => onChanged(_LoginMethod.code),
              ),
            ),
          ],
        ),
        const Divider(height: 1, color: Color(0xFFE9EDF5)),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    active ? const Color(0xFF2077FF) : const Color(0xFF858CA1),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 36 : 0,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2077FF),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormTitle extends StatelessWidget {
  const _FormTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2077FF),
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF2077FF),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.controller,
    required this.icon,
    required this.hintText,
    this.trailing,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080C3A91), blurRadius: 14, offset: Offset(0, 8)),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            color: Color(0xFF222735),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFFA3ABBD), fontSize: 17),
            prefixIcon: Icon(icon, color: const Color(0xFFA0A8BA), size: 25),
            suffixIcon: trailing,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0x662077FF)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const _CodeButton({required this.countdown, required this.onPressed});

  final int countdown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final waiting = countdown > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Center(
        widthFactor: 1,
        child: OutlinedButton(
          onPressed: waiting ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2077FF),
            side: BorderSide(
              color:
                  waiting ? const Color(0xFFD3D8E4) : const Color(0xFF2077FF),
              width: 1.3,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(92, 36),
          ),
          child: Text(waiting ? '${countdown}s' : '获取验证码'),
        ),
      ),
    );
  }
}

class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        color: const Color(0xFF9CA5BA),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2077FF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF8DBBFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.agreed, required this.onChanged});

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        GestureDetector(
          onTap: () => onChanged(!agreed),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: agreed ? const Color(0xFF2077FF) : Colors.white,
              border: Border.all(
                color:
                    agreed ? const Color(0xFF2077FF) : const Color(0xFFC8CEDB),
                width: 1.5,
              ),
            ),
            child: agreed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                : null,
          ),
        ),
        const Text('我已阅读并同意',
            style: TextStyle(color: Color(0xFF8A91A6), fontSize: 14)),
        const Text('《用户协议》',
            style: TextStyle(color: Color(0xFF2077FF), fontSize: 14)),
        const Text('与',
            style: TextStyle(color: Color(0xFF8A91A6), fontSize: 14)),
        const Text('《隐私政策》',
            style: TextStyle(color: Color(0xFF2077FF), fontSize: 14)),
      ],
    );
  }
}

class _InlineAction extends StatelessWidget {
  const _InlineAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2077FF),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x220C3A91), blurRadius: 24, offset: Offset(0, 12)),
        ],
      ),
      child: Center(
        child: Container(
          width: 48,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2077FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_LogoDot(), SizedBox(width: 8), _LogoDot()],
          ),
        ),
      ),
    );
  }
}

class _LogoDot extends StatelessWidget {
  const _LogoDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration:
          const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }
}

class _BubbleArt extends StatelessWidget {
  const _BubbleArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      height: 100,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 10,
            child: Container(
              width: 92,
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB9E1FF), Color(0xFF4BA5FF)],
                ),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x441055BC),
                      blurRadius: 22,
                      offset: Offset(0, 12)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RaisedDot(),
                  SizedBox(width: 10),
                  _RaisedDot(),
                  SizedBox(width: 10),
                  _RaisedDot()
                ],
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 16,
            child: Container(
              width: 56,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .94),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaisedDot extends StatelessWidget {
  const _RaisedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Color(0x3300399A), blurRadius: 7, offset: Offset(0, 3))
        ],
      ),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wave = Paint()..color = Colors.white.withValues(alpha: .08);
    final path = Path()
      ..moveTo(0, size.height * .46)
      ..cubicTo(
        size.width * .18,
        size.height * .62,
        size.width * .35,
        size.height * .18,
        size.width * .58,
        size.height * .36,
      )
      ..cubicTo(
        size.width * .78,
        size.height * .52,
        size.width * .74,
        size.height * .05,
        size.width,
        size.height * .2,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
