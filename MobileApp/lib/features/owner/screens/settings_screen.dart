import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/routes.dart';
import '../../../core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _teal = Color(0xFF009688);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final pageBackground = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            colorScheme.surface,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ??
            colorScheme.onSurface,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            context,
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              SwitchListTile.adaptive(
                value: isDarkMode,
                onChanged: (value) {
                  setThemeMode(
                    ref,
                    value ? ThemeMode.dark : ThemeMode.light,
                  );
                },
                title: const Text('Dark mode'),
                subtitle:
                    const Text('Use a darker color scheme across the app'),
                secondary: const Icon(Icons.dark_mode_outlined, color: _teal),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            context,
            title: 'Shortcuts',
            icon: Icons.tune,
            children: [
              _actionTile(
                context,
                icon: Icons.person_outline,
                title: 'Edit profile details',
                subtitle: 'Name, email, and phone number',
                onTap: () => Navigator.pushNamed(context, Routes.userProfile),
              ),
              const Divider(height: 1),
              _actionTile(
                context,
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: 'Manage your login credentials',
                onTap: () => Navigator.pushNamed(context, Routes.userProfile),
              ),
              const Divider(height: 1),
              _actionTile(
                context,
                icon: Icons.pets_outlined,
                title: 'Update pet details',
                subtitle: 'Edit pet name, breed, and other info',
                onTap: () => Navigator.pushNamed(context, Routes.userProfile),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            context,
            title: 'About',
            icon: Icons.info_outline,
            children: [
              _infoRow(
                context,
                Icons.notifications_active_outlined,
                'Notifications',
                'Real-time alerts for geofence and activity events',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                Icons.cloud_sync_outlined,
                'Sync',
                'Your data stays synced with the connected account',
              ),
              const Divider(height: 1),
              _infoRow(
                context,
                Icons.shield_outlined,
                'Privacy',
                'Profile and pet data are managed from the profile page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = Theme.of(context).cardColor;
    final shadowColor = isDarkTheme
        ? Colors.black.withOpacity(0.35)
        : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _teal, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _teal),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.72)),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _teal),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.72)),
      ),
    );
  }
}
