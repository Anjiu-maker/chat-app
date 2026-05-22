import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/session_store.dart';
import '../../../shared/widgets/app_chrome.dart';
import '../../../shared/widgets/avatar_widgets.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _api = ApiClient();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    final user = SessionStore.instance.user;
    _nicknameController.text = user?.nickname ?? '';
    _bioController.text = user?.bio ?? '';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PhonePageFrame(
        child: AnimatedBuilder(
          animation: SessionStore.instance,
          builder: (context, _) {
            final user = SessionStore.instance.user;
            return Stack(
              children: [
                BlueHeader(
                  title: '个人资料',
                  height: 166,
                  leading: HeaderIconButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                WhitePanel(
                  top: 124,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                    children: [
                      Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            UserInitialAvatar(
                              name: user?.nickname ?? '用户',
                              avatarUrl: user?.avatarUrl,
                              size: 96,
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: _RoundActionButton(
                                busy: _uploadingAvatar,
                                icon: Icons.photo_camera_rounded,
                                onTap: _pickAvatar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Section(
                        child: Form(
                          key: _profileFormKey,
                          child: Column(
                            children: [
                              _InputField(
                                controller: _nicknameController,
                                icon: Icons.person_outline_rounded,
                                label: '用户名',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '请输入用户名';
                                  }
                                  if (value.trim().length > 80) {
                                    return '用户名不能超过 80 个字符';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _bioController,
                                icon: Icons.edit_note_rounded,
                                label: '个人签名',
                                maxLines: 3,
                                validator: (value) {
                                  if ((value ?? '').trim().length > 120) {
                                    return '个人签名不能超过 120 个字符';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _savingProfile ? null : _saveProfile,
                                icon: _savingProfile
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded),
                                label: const Text('保存资料'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        child: Form(
                          key: _passwordFormKey,
                          child: Column(
                            children: [
                              _InputField(
                                controller: _currentPasswordController,
                                icon: Icons.lock_outline_rounded,
                                label: '当前密码',
                                obscureText: !_passwordVisible,
                                validator: _passwordValidator,
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _newPasswordController,
                                icon: Icons.password_rounded,
                                label: '新密码',
                                obscureText: !_passwordVisible,
                                validator: _passwordValidator,
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _confirmPasswordController,
                                icon: Icons.verified_user_outlined,
                                label: '确认新密码',
                                obscureText: !_passwordVisible,
                                validator: (value) {
                                  final message = _passwordValidator(value);
                                  if (message != null) return message;
                                  if (value != _newPasswordController.text) {
                                    return '两次输入的新密码不一致';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => setState(
                                    () => _passwordVisible = !_passwordVisible,
                                  ),
                                  icon: Icon(
                                    _passwordVisible
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  label: Text(
                                    _passwordVisible ? '隐藏密码' : '显示密码',
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed:
                                    _savingPassword ? null : _savePassword,
                                icon: _savingPassword
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.shield_rounded),
                                label: const Text('修改密码'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  backgroundColor: const Color(0xFF1E2636),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.length < 8) return '密码至少 8 位';
    if (text.length > 64) return '密码不能超过 64 位';
    return null;
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;

      setState(() => _uploadingAvatar = true);
      if (file.bytes != null) {
        await _api.uploadAvatarBytes(
          bytes: file.bytes!,
          filename: file.name,
        );
      } else if (file.path != null) {
        await _api.uploadAvatar(File(file.path!));
      } else {
        _showMessage('无法读取头像文件');
        return;
      }
      _showMessage('头像已更新');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('头像上传失败');
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _savingProfile = true);
    try {
      await _api.updateMe(
        nickname: _nicknameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      _showMessage('资料已保存');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('保存失败');
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _savingPassword = true);
    try {
      await _api.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('密码已修改');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('修改失败');
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C3A91),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.icon,
    required this.label,
    this.maxLines = 1,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final int maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF6F8FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.busy,
    required this.icon,
    required this.onTap,
  });

  final bool busy;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2478FF),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
