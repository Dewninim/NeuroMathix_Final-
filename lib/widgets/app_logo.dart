import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final bool white;
  final double size;

  const AppLogo({super.key, this.white = true, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final color = white ? Colors.white : const Color(0xFF0F172A);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.psychology_outlined, color: color, size: size),
        const SizedBox(width: 6),
        Text(
          'NEUROMATHIX',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
