import 'package:flutter/material.dart';

class BlueHeader extends StatelessWidget {
  const BlueHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.height = 218,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2478FF),
                    Color(0xFF2E8BFF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xDFFFFFFF),
                              fontSize: 16,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (final action in actions) ...[
                    const SizedBox(width: 10),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: .14),
      shape: const CircleBorder(),
      elevation: filled ? 2 : 0,
      shadowColor: const Color(0x1A111827),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 28,
            color: filled ? const Color(0xFF2478FF) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class SoftSearchBar extends StatelessWidget {
  const SoftSearchBar({
    required this.hintText,
    this.onTap,
    super.key,
  });

  final String hintText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080C3A91),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF9DA6B8),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hintText,
                  style: const TextStyle(
                    color: Color(0xFF9AA2B4),
                    fontSize: 16,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WhitePanel extends StatelessWidget {
  const WhitePanel({
    required this.child,
    this.top = 196,
    super.key,
  });

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      top: top,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A0B3C91),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class PhonePageFrame extends StatelessWidget {
  const PhonePageFrame({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pageWidth = width > 520 ? 430.0 : width;

        return ColoredBox(
          color: width > 520 ? const Color(0xFFF4F7FF) : Colors.white,
          child: Center(
            child: SizedBox(
              width: pageWidth,
              height: constraints.maxHeight,
              child: ClipRRect(
                borderRadius:
                    width > 520 ? BorderRadius.circular(32) : BorderRadius.zero,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.index,
    required this.onChanged,
    this.messageBadge = 0,
    super.key,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final int messageBadge;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.chat_bubble_rounded,
        '消息',
        messageBadge > 0 ? messageBadge : null,
      ),
      (Icons.person_rounded, '联系人', null),
      (Icons.groups_rounded, '群组', null),
      (Icons.person_rounded, '我', null),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 78,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 18,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _BottomItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  badge: items[i].$3,
                  active: index == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2478FF) : const Color(0xFF9AA0B3);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: active ? 48 : 38,
            height: 34,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEAF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, color: color, size: active ? 29 : 28),
                if (badge != null)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: UnreadBadge(count: badge!, compact: true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    required this.count,
    this.compact = false,
    this.red = false,
    super.key,
  });

  final int count;
  final bool compact;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 22 : 28,
        minHeight: compact ? 22 : 28,
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: red ? const Color(0xFFFF4D5E) : const Color(0xFF2478FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
