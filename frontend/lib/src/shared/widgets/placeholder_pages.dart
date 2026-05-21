import 'package:flutter/material.dart';

class SimplePlaceholderPage extends StatelessWidget {
  const SimplePlaceholderPage({
    required this.title,
    required this.icon,
    required this.label,
    super.key,
  });

  final String title;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF2478FF), size: 56),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF222735),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF858CA1),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
