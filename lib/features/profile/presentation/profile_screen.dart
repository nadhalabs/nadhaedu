import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_breakpoints.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/core/theme/app_tokens.dart';
import 'package:learning_platform/core/widgets/content_states.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/profile/application/profile_providers.dart';
import 'package:learning_platform/features/profile/domain/learner_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = AppBreakpoints.fromWidth(width);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Account'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.profile == null) {
            return const LoadingView(label: 'Loading profile');
          }
          if (state.failure != null && state.profile == null) {
            return ErrorView(
              onAction: () =>
                  ref.read(profileControllerProvider.notifier).loadProfile(),
            );
          }

          final profile =
              state.profile ??
              LearnerProfile(
                id: 'unknown',
                email: 'learner@example.com',
                displayName: 'Learner',
                memberSince: DateTime.now(),
              );

          if (sizeClass != WindowSizeClass.expanded ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return _MobileProfileLayout(profile: profile);
          } else {
            return _ExpandedProfileLayout(profile: profile);
          }
        },
      ),
    );
  }
}

class _MobileProfileLayout extends StatelessWidget {
  const _MobileProfileLayout({required this.profile});
  final LearnerProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.medium),
      children: [
        _ProfileHeaderCard(profile: profile),
        const SizedBox(height: AppSpacing.large),
        _ProfileNavigationCards(),
        const SizedBox(height: AppSpacing.large),
        _SignOutButton(),
      ],
    );
  }
}

class _ExpandedProfileLayout extends StatelessWidget {
  const _ExpandedProfileLayout({required this.profile});
  final LearnerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.large),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _ProfileHeaderCard(profile: profile),
                  const SizedBox(height: AppSpacing.large),
                  _SignOutButton(),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.large),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(child: _ProfileNavigationCards()),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});
  final LearnerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: AppPalette.softSurface(context, AppPalette.sky),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: colorScheme.primary,
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : 'L',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.medium),
            Text(
              profile.displayName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              profile.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (profile.phone != null && profile.phone!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                profile.phone!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.medium),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.editProfile),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
            ),
            if (profile.learningInterests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: profile.learningInterests.map((interest) {
                  return Chip(
                    label: Text(interest),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileNavigationCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('My Certificates'),
                subtitle: const Text('View and verify your earned credentials'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.certificates),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Downloads & Storage'),
                subtitle: const Text(
                  'Manage downloaded media and storage usage',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.downloads),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.card_membership_outlined),
                title: const Text('Subscription & Billing'),
                subtitle: const Text('Manage subscription tier and renewals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.subscriptionManagement),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('Account & Security'),
                subtitle: const Text('Password, active sessions, and deletion'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.security),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Settings & Preferences'),
                subtitle: const Text(
                  'Theme, playback, accessibility, and notifications',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        side: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      icon: const Icon(Icons.logout),
      label: const Text('Sign Out'),
      onPressed: () async {
        await ref.read(authControllerProvider.notifier).signOut();
        if (context.mounted) {
          context.go(AppRoutes.login);
        }
      },
    );
  }
}
