import 'package:flutter/material.dart';

import '../models/student_learning_models.dart';

const Color neuromathixNavy = Color(0xFF10345E);
const Color neuromathixBlue = Color(0xFF1B63E8);
const Color neuromathixText = Color(0xFF11131B);
const Color neuromathixMuted = Color(0xFF687694);
const Color neuromathixBorder = Color(0xFFE4E8F0);
const Color neuromathixSurface = Color(0xFFF8FAFD);

class StudentAppShell extends StatelessWidget {
  final StudentNavSection activeSection;
  final String userName;
  final int notificationCount;
  final Widget child;
  final ValueChanged<StudentNavSection> onSectionSelected;

  const StudentAppShell({
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
        final isCompact = constraints.maxWidth < 760;

        if (isCompact) {
          return Scaffold(
            backgroundColor: Colors.white,
            drawer: SizedBox(
              width: 240,
              child: StudentSidebar(
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
              StudentSidebar(
                activeSection: activeSection,
                onSectionSelected: onSectionSelected,
              ),
              Expanded(
                child: Column(
                  children: [
                    StudentTopBar(
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

class StudentTopBar extends StatelessWidget {
  final String userName;
  final int notificationCount;

  const StudentTopBar({
    super.key,
    required this.userName,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 44),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: neuromathixBorder)),
      ),
      child: Row(
        children: [
          Text(
            'Hi, $userName',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: neuromathixText,
            ),
          ),
          const Spacer(),
          NotificationBell(count: notificationCount),
          const SizedBox(width: 20),
          UserInitialAvatar(userName: userName),
        ],
      ),
    );
  }
}

class StudentSidebar extends StatelessWidget {
  final StudentNavSection activeSection;
  final bool expanded;
  final ValueChanged<StudentNavSection> onSectionSelected;

  const StudentSidebar({
    super.key,
    required this.activeSection,
    required this.onSectionSelected,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(
        StudentNavSection.dashboard,
        Icons.grid_view_rounded,
        'Dashboard',
      ),
      _SidebarItem(
        StudentNavSection.downloads,
        Icons.file_download_outlined,
        'Downloads',
      ),
      _SidebarItem(
        StudentNavSection.modules,
        Icons.menu_book_outlined,
        'Modules',
      ),
      _SidebarItem(
        StudentNavSection.aiFeedback,
        Icons.device_hub_outlined,
        'AI Feedback',
      ),
      _SidebarItem(
        StudentNavSection.schedule,
        Icons.calendar_month_outlined,
        'Schedule',
      ),
      _SidebarItem(
        StudentNavSection.analytics,
        Icons.show_chart_outlined,
        'Analytics',
      ),
      _SidebarItem(
        StudentNavSection.settings,
        Icons.settings_outlined,
        'Settings',
      ),
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
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceEvenly,
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'NEUROMATHIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                  const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
            if (!expanded) ...[
              const SizedBox(height: 6),
              const Text(
                'NEUROMATHIX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 0,
                ),
              ),
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
          ],
        ),
      ),
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
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: Colors.white, size: 28),
          if (expanded) ...[
            const SizedBox(width: 14),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  final StudentNavSection section;
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
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.notifications_none_rounded,
              size: 32,
              color: Colors.black,
            ),
          ),
          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
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
    final trimmedName = userName.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF0D315E),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 26,
        ),
      ),
    );
  }
}

class SectionPlaceholder extends StatelessWidget {
  final String title;
  final String message;

  const SectionPlaceholder({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: neuromathixBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: neuromathixMuted,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
