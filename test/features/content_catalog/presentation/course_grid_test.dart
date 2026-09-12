import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_platform/features/content_catalog/data/foundation_catalog_data_source.dart';
import 'package:learning_platform/features/content_catalog/domain/catalog_query.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_card.dart';
import 'package:learning_platform/features/content_catalog/presentation/widgets/course_grid.dart';
import 'package:learning_platform/features/entitlements/application/entitlement_providers.dart';
import 'package:learning_platform/features/entitlements/domain/access_decision.dart';
import 'package:learning_platform/features/entitlements/domain/access_reason.dart';

void main() {
  testWidgets('large course grids build visible cards lazily', (tester) async {
    final page = await FoundationCatalogDataSource().fetchCourses(
      const CatalogQuery(pageSize: 36),
    );
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessDecisionProvider.overrideWith(
            (ref, query) => AccessDecision(
              resourceType: query.resourceType,
              resourceId: query.resourceId,
              canAccess: true,
              state: AccessState.free,
              reason: AccessReason.freeContent,
              evaluatedAt: DateTime.utc(2026, 8, 31),
            ),
          ),
        ],
        child: MaterialApp(
          home: CourseGrid(
            courses: page.items,
            bookmarkedIds: const {},
            onBookmark: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(CourseCard), findsWidgets);
    expect(
      find.byType(CourseCard).evaluate().length,
      lessThan(page.items.length),
    );
    expect(find.byTooltip('Bookmark course'), findsWidgets);
  });
}
