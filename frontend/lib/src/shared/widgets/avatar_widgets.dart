import 'package:flutter/material.dart';

class UserInitialAvatar extends StatelessWidget {
  const UserInitialAvatar({
    required this.name,
    this.size = 58,
    this.avatarUrl,
    this.showOnline = false,
    this.online = false,
    super.key,
  });

  final String name;
  final double size;
  final String? avatarUrl;
  final bool showOnline;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipOval(
              child: avatarUrl?.isNotEmpty == true
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _InitialAvatarFace(name: name, size: size),
                    )
                  : _InitialAvatarFace(name: name, size: size),
            ),
          ),
          if (showOnline && online)
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: size * .22,
                height: size * .22,
                decoration: BoxDecoration(
                  color: const Color(0xFF53D75A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GroupInitialAvatar extends StatelessWidget {
  const GroupInitialAvatar({
    required this.title,
    this.size = 58,
    super.key,
  });

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6AA5FF), Color(0xFF185CF2)],
        ),
      ),
      child: Text(
        title.isEmpty ? '群' : title.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class SystemAvatar extends StatelessWidget {
  const SystemAvatar({
    required this.icon,
    required this.colors,
    this.iconColor = Colors.white,
    this.size = 58,
    super.key,
  });

  final IconData icon;
  final List<Color> colors;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(icon, color: iconColor, size: size * .45),
    );
  }
}

class _InitialAvatarFace extends StatelessWidget {
  const _InitialAvatarFace({
    required this.name,
    required this.size,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6AA5FF), Color(0xFF185CF2)],
        ),
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '用' : name.substring(0, 1),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
