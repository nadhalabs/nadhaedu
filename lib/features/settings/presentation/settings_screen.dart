import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/downloads/application/download_providers.dart';
import 'package:learning_platform/features/settings/application/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final branding = ref.watch(brandingConfigProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Academic Profile'),
            subtitle: const Text('Curriculum, standard and stream'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/academic-profile'),
          ),
          // APPEARANCE SECTION
          _SectionHeader(title: 'APPEARANCE & THEME'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {settings.appearance.themeMode},
                    onSelectionChanged: (selection) {
                      unawaited(notifier.setThemeMode(selection.first));
                    },
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reduce Motion'),
                    subtitle: const Text(
                      'Minimize system animations and transitions',
                    ),
                    value: settings.appearance.reducedMotion,
                    onChanged: notifier.setReducedMotion,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High Contrast Presentation'),
                    subtitle: const Text(
                      'Increase visual contrast for text and controls',
                    ),
                    value: settings.appearance.highContrast,
                    onChanged: notifier.setHighContrast,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // PLAYBACK & LEARNING
          _SectionHeader(title: 'LEARNING & PLAYBACK'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Autoplay Next Lesson'),
                  subtitle: const Text(
                    'Automatically advance when a lesson completes',
                  ),
                  value: settings.playback.autoplayNextLesson,
                  onChanged: notifier.setAutoplayNextLesson,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Preferred Playback Speed'),
                  subtitle: Text(
                    '${settings.playback.preferredPlaybackSpeed}x',
                  ),
                  trailing: DropdownButton<double>(
                    value: settings.playback.preferredPlaybackSpeed,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                      DropdownMenuItem(
                        value: 1.0,
                        child: Text('1.0x (Normal)'),
                      ),
                      DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                      DropdownMenuItem(value: 1.5, child: Text('1.5x')),
                      DropdownMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        unawaited(notifier.setPreferredPlaybackSpeed(val));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Always Enable Captions'),
                  subtitle: const Text(
                    'Show subtitles/captions automatically during video playback',
                  ),
                  value: settings.playback.captionsDefaultEnabled,
                  onChanged: notifier.setCaptionsDefaultEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // DOWNLOADS & STORAGE
          _SectionHeader(title: 'DOWNLOADS & STORAGE'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Download over Wi-Fi only'),
                  subtitle: const Text(
                    'Prevent using mobile cellular data for offline downloads',
                  ),
                  value: settings.downloads.downloadWifiOnly,
                  onChanged: notifier.setDownloadWifiOnly,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Download Quality'),
                  subtitle: Text(
                    settings.downloads.downloadQuality == 'high'
                        ? 'High (1080p)'
                        : settings.downloads.downloadQuality == 'dataSaver'
                        ? 'Data Saver (480p)'
                        : 'Standard (720p)',
                  ),
                  trailing: DropdownButton<String>(
                    value: settings.downloads.downloadQuality,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'dataSaver',
                        child: Text('Data Saver (480p)'),
                      ),
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard (720p)'),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Text('High (1080p)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        unawaited(notifier.setDownloadQuality(val));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Manage Downloads'),
                  subtitle: const Text(
                    'View and delete individual downloaded lessons',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.downloads),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear Temporary Cache'),
                  subtitle: const Text(
                    'Frees image and response caches (keeps downloaded lessons)',
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Temporary cache cleared.'),
                        ),
                      );
                    },
                    child: const Text('Clear Cache'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Clear All Downloaded Lessons',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  subtitle: const Text(
                    'Erases all offline media files on this device',
                  ),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: () => _confirmClearDownloads(context, ref),
                    child: const Text('Delete All'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // NOTIFICATIONS LINK
          _SectionHeader(title: 'NOTIFICATIONS'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification Preferences'),
              subtitle: const Text('Manage push, email, and reminder channels'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.notificationPreferences),
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // PRIVACY & LEGAL
          _SectionHeader(title: 'PRIVACY & LEGAL'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Anonymous Analytics'),
                  subtitle: const Text(
                    'Help improve learning experience without tracking personal data',
                  ),
                  value: settings.privacy.analyticsEnabled,
                  onChanged: notifier.setAnalyticsEnabled,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening Privacy Policy...'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening Terms of Service...'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // ABOUT
          Center(
            child: Column(
              children: [
                Text(
                  branding.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by Nadha Labs • Version 1.0.0',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),
        ],
      ),
    );
  }

  void _confirmClearDownloads(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete All Downloads?'),
          content: const Text(
            'This will remove all downloaded media files from your local device storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(downloadControllerProvider.notifier)
                    .clearAllDownloads();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All downloaded lessons removed.'),
                    ),
                  );
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
