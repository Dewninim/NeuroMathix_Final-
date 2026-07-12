// Dashboard Shell - proj2 UI with proj1 pages wired in
// Navigation items and their target pages:
//   0 Dashboard      → StudentDashboardPage / TeacherDashboardPage
//   1 Upload Material → (placeholder)
//   2 AI Feedback    → ExplainableAiFeedbackPage
//   3 Review Schedule→ ReviewSchedulePage
//   4 Analytics      → AnalyticsPage
//   5 Settings       → ProfilePage

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'brain_logo.dart';

class DashboardShell extends StatefulWidget {
  final Widget child;
  final int selectedIndex;

  const DashboardShell({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with SingleTickerProviderStateMixin {
  bool _sidebarExpanded = false;
  int? _hoveredIndex;
  late AnimationController _contentController;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  // Username pulled from Firebase Auth
  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'User';
    return user.displayName?.split(' ').first ??
        user.email?.split('@').first ??
        'User';
  }

  String get _initial {
    final n = _displayName;
    return n.isEmpty ? 'U' : n[0].toUpperCase();
  }

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', '/dashboard'),
    _NavItem(Icons.file_download_outlined, 'Upload Material', '/upload'),
    _NavItem(Icons.psychology_alt_rounded, 'AI Feedback', '/ai-feedback'),
    _NavItem(Icons.calendar_month_rounded, 'Review Schedule', '/review'),
    _NavItem(Icons.show_chart_rounded, 'Analytics', '/analytics'),
    _NavItem(Icons.settings_rounded, 'Settings', '/profile'),
  ];

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _navigateTo(String route) async {
    await _contentController.reverse();
    if (!mounted) return;
    Navigator.pushNamed(context, route);
    _contentController.forward();
  }

  void _toggleSidebar() => setState(() => _sidebarExpanded = !_sidebarExpanded);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Row(
        children: [
          // ── Sidebar ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            width: _sidebarExpanded ? 240 : 72,
            decoration: const BoxDecoration(
              color: Color(0xFF1a2f5e),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(2, 0)),
              ],
            ),
            child: Column(
              children: [
                // Logo + hamburger
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: _sidebarExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _toggleSidebar,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: Icon(
                              _sidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                              color: Colors.white.withValues(alpha: 0.80),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      if (_sidebarExpanded) ...[
                        const SizedBox(width: 10),
                        const BrainLogo(size: 26),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'NEUROMATHIX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Container(height: 1, color: Colors.white12),
                const SizedBox(height: 8),

                // Nav items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _navItems.length,
                    itemBuilder: (context, i) {
                      final item = _navItems[i];
                      final isSelected = widget.selectedIndex == i;
                      final isHovered = _hoveredIndex == i;

                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = i),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: Tooltip(
                          message: _sidebarExpanded ? '' : item.label,
                          preferBelow: false,
                          child: GestureDetector(
                            onTap: () => _navigateTo(item.route),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: EdgeInsets.symmetric(
                                horizontal: _sidebarExpanded ? 14 : 0,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : isHovered
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: _sidebarExpanded
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    color: isSelected || isHovered
                                        ? Colors.white
                                        : Colors.white54,
                                    size: 22,
                                  ),
                                  if (_sidebarExpanded) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: isSelected || isHovered
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Profile at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredIndex = 99),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: GestureDetector(
                      onTap: () => _navigateTo('/profile'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 14 : 0,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _hoveredIndex == 99
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: _sidebarExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Text(
                                      'View Profile',
                                      style: TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Main content ──
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Hi, $_displayName',
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_rounded,
                              color: Color(0xFF374151), size: 24),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('3',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _navigateTo('/profile'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1F4E95),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}
