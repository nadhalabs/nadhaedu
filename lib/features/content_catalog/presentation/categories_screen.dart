import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_platform/core/routing/app_router.dart';
import 'package:learning_platform/core/theme/app_spacing.dart';
import 'package:learning_platform/features/content_catalog/application/catalog_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: ElevatedButton(
            onPressed: () => ref.invalidate(categoriesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (items) => GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.medium),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisExtent: 120,
            mainAxisSpacing: AppSpacing.medium,
            crossAxisSpacing: AppSpacing.medium,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final category = items[index];
            return Card(
              child: InkWell(
                onTap: () async {
                  final catalog = ref.read(catalogProvider);
                  await ref
                      .read(catalogProvider.notifier)
                      .updateQuery(
                        catalog.query.copyWith(categoryId: category.id),
                      );
                  if (context.mounted) {
                    context.go(AppRoutes.discover);
                  }
                },
                child: Center(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
