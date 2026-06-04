// Shared widgets used across dashboard tabs
// Contains DashboardAppBar, NotificationsScreen, and GradientCard

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/screens/login_screen.dart';
import '../data/owner_repository.dart';
import '../location/providers/alerts_provider.dart';
import '../../../core/constants/routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardAppBar
// Changed from StatelessWidget → ConsumerWidget so it can read alertsProvider
// and show the live notification count badge on the bell icon.
// ─────────────────────────────────────────────────────────────────────────────

class DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;

  const DashboardAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Live count from alertsProvider — updates instantly when any feature
    // (location geofence breach or activity impact) adds a new alert.
    final alertCount = ref.watch(alertsProvider).length;

    return AppBar(
      title: Text(title),
      backgroundColor:
          Theme.of(context).appBarTheme.backgroundColor ?? colorScheme.surface,
      foregroundColor: Theme.of(context).appBarTheme.foregroundColor ??
          colorScheme.onSurface,
      elevation: Theme.of(context).appBarTheme.elevation ?? 1,
      actions: [
        // ── Notifications bell with red badge ──────────────────────────────
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: colorScheme.onSurface),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            // Show badge only when there are unread alerts
            if (alertCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      alertCount > 99 ? '99+' : '$alertCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ── Profile popup menu ─────────────────────────────────────────────
        PopupMenuButton<String>(
          icon: const CircleAvatar(
            backgroundColor: Color.fromARGB(255, 0, 150, 136),
            child: Icon(Icons.person, color: Colors.white),
          ),
          onSelected: (value) => _handleMenuAction(context, value, ref),
          itemBuilder: (_) => [
            _menuItem('profile', Icons.person, 'My Profile'),
            _menuItem('settings', Icons.settings, 'Settings'),
            _menuItem('help', Icons.help_outline, 'Help & Support'),
            _menuItem('about', Icons.info_outline, 'About'),
            const PopupMenuDivider(),
            _menuItem('logout', Icons.logout, 'Logout', color: Colors.red),
          ],
        ),

        const SizedBox(width: 10),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String value, WidgetRef ref) {
    switch (value) {
      case 'profile':
        //_showInfoDialog(context, 'My Profile', 'User profile details go here.');
        Navigator.pushNamed(context, Routes.userProfile);
        break;
      case 'settings':
        Navigator.pushNamed(context, Routes.settings);
        break;
      case 'help':
        _showInfoDialog(context, 'Help & Support', 'Help content goes here.');
        break;
      case 'about':
        _showInfoDialog(context, 'About', 'App information goes here.');
        break;
      case 'logout':
        _confirmLogout(context, ref);
        break;
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear all in-app alerts on logout so they don't
              // bleed into the next user's session
              ref.read(alertsProvider.notifier).clearAll();

              final ownerRepository = OwnerRepository();
              await ownerRepository.signOut();

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen
// Shows all in-app alerts from all three features (location, activity, health).
// Alerts are sourced from alertsProvider which is written to by:
//   • geofenceMonitorProvider  (location feature — zone breaches)
//   • activityAlertMonitorProvider (activity feature — impact detected)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static const _teal = Color(0xFF009688);

  // Pick an icon based on the alert title prefix
  IconData _iconForAlert(String title) {
    if (title.contains('Zone') || title.contains('zone')) {
      return Icons.location_on;
    } else if (title.contains('Impact')) {
      return Icons.warning_amber_rounded;
    } else if (title.contains('Health') || title.contains('health')) {
      return Icons.favorite;
    }
    return Icons.notifications;
  }

  // Pick a colour based on severity keywords in the title
  Color _colorForAlert(String title) {
    if (title.contains('HIGH') || title.contains('Zone')) {
      return Colors.red.shade600;
    } else if (title.contains('MEDIUM')) {
      return Colors.orange.shade600;
    } else if (title.contains('LOW')) {
      return Colors.blue.shade600;
    }
    return _teal;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final alerts = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            colorScheme.surface,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ??
            colorScheme.onSurface,
        elevation: Theme.of(context).appBarTheme.elevation ?? 1,
        actions: [
          if (alerts.isNotEmpty)
            TextButton(
              onPressed: () {
                ref.read(alertsProvider.notifier).clearAll();
              },
              child: const Text(
                'Clear all',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: alerts.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final color = _colorForAlert(alert.title);
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.3
                              : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForAlert(alert.title),
                        color: color,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          alert.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(alert.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    // Swipe-to-dismiss not needed — clear all handles bulk removal
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: _teal,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2E2C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zone breaches and impact alerts\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF607D7B),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GradientCard — unchanged
// ─────────────────────────────────────────────────────────────────────────────

class GradientCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String trailing;
  final List<Color> colors;

  const GradientCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardTextColor = colors.first.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Use a solid color when a single color is provided, otherwise a gradient
        color: colors.length == 1 ? colors[0] : null,
        gradient: colors.length > 1
            ? LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cardTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: cardTextColor.withOpacity(0.75)),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: TextStyle(
              color: cardTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
