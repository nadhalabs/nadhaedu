import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/notifications/application/notification_providers.dart';

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationPreferencesControllerProvider);
    final notifier = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notification Preferences')),
        body: const LoadingView(label: 'Loading preferences'),
      );
    }

    final prefs = state.preferences;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          // Push Notifications Section
          Text(
            'PUSH NOTIFICATIONS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Course Updates'),
                  subtitle: const Text(
                    'New lessons, materials, and announcements',
                  ),
                  value: prefs.pushCourseUpdates,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushCourseUpdates: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Learning Reminders'),
                  subtitle: const Text(
                    'Streak alerts and scheduled study times',
                  ),
                  value: prefs.pushLearningReminders,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushLearningReminders: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Live Classes'),
                  subtitle: const Text(
                    'Upcoming live interactive session alerts',
                  ),
                  value: prefs.pushLiveClasses,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushLiveClasses: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Assessment Updates'),
                  subtitle: const Text('Grading results and test feedback'),
                  value: prefs.pushAssessmentUpdates,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushAssessmentUpdates: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Certificate Issuance'),
                  subtitle: const Text(
                    'Notifications when credentials are ready',
                  ),
                  value: prefs.pushCertificateUpdates,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushCertificateUpdates: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Billing & Payments'),
                  subtitle: const Text(
                    'Renewal notices and receipt confirmations',
                  ),
                  value: prefs.pushPaymentEvents,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(pushPaymentEvents: val),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Security & Account Alerts'),
                  subtitle: Text('Always enabled for your account safety'),
                  trailing: Icon(Icons.check, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),

          // Email Notifications Section
          Text(
            'EMAIL NOTIFICATIONS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Course Updates & Digests'),
                  subtitle: const Text('Weekly summaries and course progress'),
                  value: prefs.emailCourseUpdates,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(emailCourseUpdates: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Learning Reminders'),
                  subtitle: const Text('Study goals and milestone recaps'),
                  value: prefs.emailLearningReminders,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(emailLearningReminders: val),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Special Offers & Recommendations'),
                  subtitle: const Text('New courses and platform discounts'),
                  value: prefs.emailMarketing,
                  onChanged: (val) => notifier.updatePreferences(
                    prefs.copyWith(emailMarketing: val),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Security & Password Emails'),
                  subtitle: Text(
                    'Always enabled for important security notices',
                  ),
                  trailing: Icon(Icons.check, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.large),
        ],
      ),
    );
  }
}
