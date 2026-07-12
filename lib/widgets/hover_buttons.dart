import 'package:flutter/material.dart';

class HoverFilledButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;

  const HoverFilledButton({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
  });

  @override
  State<HoverFilledButton> createState() => _HoverFilledButtonState();
}

class _HoverFilledButtonState extends State<HoverFilledButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final bg = hovering ? const Color(0xFF1F4E95) : Colors.white;
    final fg = hovering ? Colors.white : const Color(0xFF1F4E95);

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: const Color(0xFF1F4E95).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.icon != null) ...[
                    const SizedBox(width: 6),
                    Icon(widget.icon, size: 16, color: fg),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HoverOutlineButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const HoverOutlineButton({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  State<HoverOutlineButton> createState() => _HoverOutlineButtonState();
}

class _HoverOutlineButtonState extends State<HoverOutlineButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final bg = hovering ? const Color(0xFF1F4E95) : Colors.transparent;
    final fg = Colors.white;
    final border = hovering ? const Color(0xFF1F4E95) : Colors.white70;

    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: widget.onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Text(
                'I have an account',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TopSignInButton extends StatefulWidget {
  final VoidCallback onTap;

  const TopSignInButton({super.key, required this.onTap});

  @override
  State<TopSignInButton> createState() => _TopSignInButtonState();
}

class _TopSignInButtonState extends State<TopSignInButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: hovering
              ? const Color(0xFF1F4E95)
              : Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white70),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              child: Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
