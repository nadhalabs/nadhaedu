import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/entitlements/domain/access_policy.dart';

void main() {
  group('AccessPolicy inheritance and overrides', () {
    test('inherits course policy when module and lesson do not override', () {
      const coursePolicy = AccessPolicy.premium();
      const modulePolicy = AccessPolicy.inherit();
      const lessonPolicy = AccessPolicy.inherit();

      final resolved = AccessPolicy.resolve(
        coursePolicy: coursePolicy,
        modulePolicy: modulePolicy,
        lessonPolicy: lessonPolicy,
      );

      expect(resolved.kind, equals(AccessPolicyKind.premium));
      expect(resolved.isPremium, isTrue);
      expect(resolved.isFree, isFalse);
    });

    test('module free override supersedes premium course policy', () {
      const coursePolicy = AccessPolicy.premium();
      const modulePolicy = AccessPolicy.free();
      const lessonPolicy = AccessPolicy.inherit();

      final resolved = AccessPolicy.resolve(
        coursePolicy: coursePolicy,
        modulePolicy: modulePolicy,
        lessonPolicy: lessonPolicy,
      );

      expect(resolved.kind, equals(AccessPolicyKind.free));
      expect(resolved.isFree, isTrue);
      expect(resolved.isPremium, isFalse);
    });

    test(
      'lesson preview override supersedes premium course and module policies',
      () {
        const coursePolicy = AccessPolicy.premium();
        const modulePolicy = AccessPolicy.premium();
        const lessonPolicy = AccessPolicy.preview();

        final resolved = AccessPolicy.resolve(
          coursePolicy: coursePolicy,
          modulePolicy: modulePolicy,
          lessonPolicy: lessonPolicy,
        );

        expect(resolved.kind, equals(AccessPolicyKind.preview));
        expect(resolved.isPreview, isTrue);
      },
    );

    test('lesson free override supersedes premium module and course', () {
      const coursePolicy = AccessPolicy.premium();
      const modulePolicy = AccessPolicy.premium();
      const lessonPolicy = AccessPolicy.free();

      final resolved = AccessPolicy.resolve(
        coursePolicy: coursePolicy,
        modulePolicy: modulePolicy,
        lessonPolicy: lessonPolicy,
      );

      expect(resolved.kind, equals(AccessPolicyKind.free));
      expect(resolved.isFree, isTrue);
    });

    test(
      'lesson premium override supersedes free course and module policies',
      () {
        const coursePolicy = AccessPolicy.free();
        const modulePolicy = AccessPolicy.free();
        const lessonPolicy = AccessPolicy.premium(requiredTier: 'Pro');

        final resolved = AccessPolicy.resolve(
          coursePolicy: coursePolicy,
          modulePolicy: modulePolicy,
          lessonPolicy: lessonPolicy,
        );

        expect(resolved.kind, equals(AccessPolicyKind.premium));
        expect(resolved.requiredTier, equals('Pro'));
      },
    );
  });
}
