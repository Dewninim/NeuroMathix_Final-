import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/teacher_models.dart';

const Color neuromathixNavy = Color(0xFF10345E);
const Color neuromathixBlue = Color(0xFF1B63E8);
const Color neuromathixText = Color(0xFF11131B);
const Color neuromathixMuted = Color(0xFF687694);
const Color neuromathixBorder = Color(0xFFE4E8F0);
const Color neuromathixSurface = Color(0xFFF8FAFD);

class TeacherAppShell extends StatelessWidget {
  final TeacherNavSection activeSection;
  final String userName;
  final int notificationCount;
  final Widget child;
  final ValueChanged<TeacherNavSection> onSectionSelected;

  const TeacherAppShell({
    super.key,
    required this.activeSection,
    required this.userName,
    required this.notificationCount,
    required this.child,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isCompact = w < 760;

        if (isCompact) {
          return Scaffold(
            backgroundColor: Colors.white,
            drawer: SizedBox(
              width: 240,
              child: TeacherSidebar(
                activeSection: activeSection,
                expanded: true,
                onSectionSelected: (section) {
                  Navigator.pop(context);
                  onSectionSelected(section);
                },
              ),
            ),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: neuromathixText,
              elevation: 0,
              centerTitle: false,
              title: Text(
                'Hi, $userName',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                NotificationBell(count: notificationCount),
                const SizedBox(width: 8),
                UserInitialAvatar(userName: userName),
                const SizedBox(width: 12),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: neuromathixBorder),
              ),
            ),
            body: child,
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: Row(
            children: [
              TeacherSidebar(
                activeSection: activeSection,
                onSectionSelected: onSectionSelected,
              ),
              Expanded(
                child: Column(
                  children: [
                    TeacherTopBar(
                      userName: userName,
                      notificationCount: notificationCount,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TeacherTopBar extends StatelessWidget {
  final String userName;
  final int notificationCount;

  const TeacherTopBar({
    super.key,
    required this.userName,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isSmall = c.maxWidth < 1000;

        return Container(
          height: isSmall ? 56 : 64,
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 18 : 44),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: neuromathixBorder)),
          ),
          child: Row(
            children: [
              Text(
                'Hi, $userName',
                style: TextStyle(
                  fontSize: isSmall ? 22 : 28,
                  fontWeight: FontWeight.w800,
                  color: neuromathixText,
                ),
              ),
              const Spacer(),
              NotificationBell(count: notificationCount),
              const SizedBox(width: 14),
              UserInitialAvatar(userName: userName),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _logout(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(context, '/landing', (_) => false);
  }
}

class TeacherSidebar extends StatelessWidget {
  final TeacherNavSection activeSection;
  final bool expanded;
  final ValueChanged<TeacherNavSection> onSectionSelected;

  const TeacherSidebar({
    super.key,
    required this.activeSection,
    required this.onSectionSelected,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(TeacherNavSection.dashboard, Icons.grid_view_rounded, 'Dashboard'),
      _SidebarItem(TeacherNavSection.settings, Icons.settings_outlined, 'Settings'),
    ];

    return Container(
      width: expanded ? 240 : 112,
      color: neuromathixNavy,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 26),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 18 : 0),
              child: Row(
                mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.spaceEvenly,
                children: [
                  const Icon(Icons.psychology_outlined, color: Colors.white, size: 34),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'NEUROMATHIX',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
            if (!expanded) ...[
              const SizedBox(height: 6),
              const Text('NEUROMATHIX', style: TextStyle(color: Colors.white, fontSize: 11)),
            ],
            const SizedBox(height: 38),
            for (final item in items)
              _SidebarButton(
                item: item,
                expanded: expanded,
                selected: activeSection == item.section,
                onTap: () => onSectionSelected(item.section),
              ),
            const Spacer(),
            _SidebarLogoutButton(
              expanded: expanded,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _SidebarLogoutButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarLogoutButton({
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: expanded ? double.infinity : 54,
      height: 54,
      margin: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded, color: Colors.white, size: 26),
          if (expanded) ...[
            const SizedBox(width: 14),
            const Text(
              'Logout',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: 'Logout',
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final _SidebarItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: expanded ? double.infinity : 54,
      height: 54,
      margin: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 9),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
      decoration: BoxDecoration(
        color: selected ? neuromathixBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: Colors.white, size: 28),
          if (expanded) ...[
            const SizedBox(width: 14),
            Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );

    return Tooltip(
      message: item.label,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class _SidebarItem {
  final TeacherNavSection section;
  final IconData icon;
  final String label;
  const _SidebarItem(this.section, this.icon, this.label);
}

class NotificationBell extends StatelessWidget {
  final int count;
  const NotificationBell({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.notifications_none_rounded, size: 30, color: Colors.black),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

class UserInitialAvatar extends StatelessWidget {
  final String userName;
  const UserInitialAvatar({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final trimmed = userName.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF0D315E),
      child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
    );
  }
}
