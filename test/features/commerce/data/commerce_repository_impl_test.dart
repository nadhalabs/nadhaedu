import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/commerce/data/commerce_repository_impl.dart';
import 'package:learning_platform/features/commerce/data/foundation_commerce_data_source.dart';

void main() {
  group('CommerceRepositoryImpl Tests', () {
    late CommerceRepositoryImpl repository;
    late FoundationCommerceDataSource dataSource;

    setUp(() {
      dataSource = FoundationCommerceDataSource();
      repository = CommerceRepositoryImpl(
        dataSource: dataSource,
        learnerId: 'learner_test',
      );
    });

    test(
      'caches plans on first fetch and refreshes on forceRefresh: true',
      () async {
        final plans1 = await repository.getSubscriptionPlans();
        expect(plans1, isNotEmpty);

        final plans2 = await repository.getSubscriptionPlans();
        expect(identical(plans1, plans2), isTrue); // Caching check

        final plans3 = await repository.getSubscriptionPlans(
          forceRefresh: true,
        );
        expect(plans3, isNotEmpty);
      },
    );

    test('retrieves plan and course by ID', () async {
      final plan = await repository.getSubscriptionPlanById('plan_pro_annual');
      expect(plan, isNotNull);
      expect(plan!.name, 'Pro Annual');

      final course = await repository.getCourseProductById('prod_course_1');
      expect(course, isNotNull);
      expect(course!.courseId, 'course-1');
    });

    test('validates coupon through repository', () async {
      final coupon = await repository.validateCoupon('SAVE20');
      expect(coupon, isNotNull);
      expect(coupon!.code, 'SAVE20');
    });
  });
}
