import 'package:flutter_test/flutter_test.dart';
import 'package:learning_platform/features/certificates/data/certificate_data_source.dart';
import 'package:learning_platform/features/certificates/data/foundation_certificate_data_source.dart';
import 'package:learning_platform/features/certificates/domain/certificate.dart';
import 'package:learning_platform/features/certificates/domain/certificate_eligibility.dart';

void main() {
  group('FoundationCertificateDataSource development fixture', () {
    late FoundationCertificateDataSource dataSource;
    const learnerId = 'dev-learner-id';

    setUp(() {
      dataSource = FoundationCertificateDataSource();
    });

    test('fetches pre-seeded certificates for learner', () async {
      final certs = await dataSource.fetchCertificates(learnerId);

      expect(certs.length, 2);
      expect(certs.any((c) => c.status == CertificateStatus.issued), isTrue);
      expect(certs.any((c) => c.status == CertificateStatus.revoked), isTrue);
    });

    test('paginates certificate history with a bounded cursor', () async {
      final first = await dataSource.fetchCertificatePage(learnerId, limit: 1);
      final second = await dataSource.fetchCertificatePage(
        learnerId,
        cursor: first.nextCursor,
        limit: 1,
      );

      expect(first.items, hasLength(1));
      expect(first.hasMore, isTrue);
      expect(second.items, hasLength(1));
      expect(second.nextCursor, isNull);
      expect(second.items.single.id, isNot(first.items.single.id));
    });

    test('verifies authentic active credential ID successfully', () async {
      final info = await dataSource.verifyCredential('CERT-2026-98124');

      expect(info.isValid, isTrue);
      expect(info.certificate?.learnerName, 'Alex Mercer');
      expect(info.certificate?.courseTitle, 'Modern Application Development');
      expect(info.message, contains('authentic and verified'));
    });

    test(
      'identifies and rejects revoked credential ID with authoritative reason',
      () async {
        final info = await dataSource.verifyCredential('CERT-2026-REVOKED-01');

        expect(info.isValid, isFalse);
        expect(info.certificate?.isRevoked, isTrue);
        expect(
          info.message,
          contains('superseded following academic integrity audit'),
        );
      },
    );

    test('identifies non-existent credential identifier as invalid', () async {
      final info = await dataSource.verifyCredential('CERT-NONEXISTENT-999');

      expect(info.isValid, isFalse);
      expect(info.certificate, isNull);
      expect(info.message, contains('No certificate found'));
    });

    test(
      'fails closed when authoritative eligibility services are unavailable',
      () async {
        final eligibility = await dataSource.checkEligibility(
          'course-3',
          learnerId: 'new-learner-456',
        );

        expect(eligibility.status, EligibilityStatus.unavailable);
        expect(eligibility.isEligible, isFalse);
        expect(
          () => dataSource.claimCertificate(
            'course-3',
            learnerId: 'new-learner-456',
            learnerName: 'Jordan Taylor',
          ),
          throwsA(isA<CertificateDataException>()),
        );
      },
    );

    test(
      'eligibility evaluation returns alreadyIssued for previously claimed courses',
      () async {
        final eligibility = await dataSource.checkEligibility(
          'course-1',
          learnerId: learnerId,
        );

        expect(eligibility.status, EligibilityStatus.alreadyIssued);
        expect(eligibility.isAlreadyIssued, isTrue);
      },
    );
  });
}
