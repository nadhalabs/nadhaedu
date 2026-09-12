import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nadha_cms/features/cms/presentation/theme/cms_theme.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_card.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_header.dart';
import 'package:nadha_cms/features/cms/presentation/widgets/cms_state_views.dart';
import 'package:nadha_cms/features/operations/application/cms_operations_providers.dart';

class CmsOperationsScreen extends ConsumerWidget {
  const CmsOperationsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.path,
    this.dangerous = false,
  });

  final String title;
  final String subtitle;
  final String path;
  final bool dangerous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cmsOperationsDataProvider(path));
    return Column(
      children: [
        CmsHeader(
          currentRoute: GoRouterState.of(context).uri.path,
          title: title,
          subtitle: subtitle,
        ),
        Expanded(
          child: state.when(
            loading: () =>
                const CmsLoadingView(message: 'Loading operational data…'),
            error: (error, _) => CmsErrorView(
              message: 'Unable to load this view. Please try again.',
              onRetry: () => ref.invalidate(cmsOperationsDataProvider(path)),
            ),
            data: (data) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(cmsOperationsDataProvider(path)),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (dangerous)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: CmsTheme.dangerBg,
                        border: Border.all(color: CmsTheme.dangerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'ULTIMATE CONTROL — high-impact actions require explicit confirmation and a reason.',
                        style: TextStyle(
                          color: CmsTheme.dangerText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  for (final entry in data.entries)
                    _Section(name: entry.key, value: entry.value),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.name, required this.value});
  final String name;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final rows = value is List ? value as List : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CmsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _label(name),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: CmsTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (rows != null && rows.isEmpty)
              const Text(
                'No records.',
                style: TextStyle(color: CmsTheme.textMuted),
              )
            else if (rows != null)
              for (final row in rows.take(100)) _Record(value: row)
            else
              _Record(value: value),
          ],
        ),
      ),
    );
  }
}

class _Record extends StatelessWidget {
  const _Record({required this.value});
  final Object? value;
  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      final map = Map<String, Object?>.from(value as Map);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CmsTheme.borderColor)),
        ),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          children: map.entries
              .map(
                (entry) => SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(entry.key),
                        style: const TextStyle(
                          color: CmsTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        '${entry.value ?? '—'}',
                        style: const TextStyle(
                          color: CmsTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    return SelectableText(
      '${value ?? '—'}',
      style: const TextStyle(color: CmsTheme.textSecondary),
    );
  }
}

String _label(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .replaceAll('_', ' ')
    .trim()
    .split(' ')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');
