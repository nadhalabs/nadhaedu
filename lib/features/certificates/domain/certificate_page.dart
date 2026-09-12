import 'package:learning_platform/features/certificates/domain/certificate.dart';

final class CertificatePage {
  const CertificatePage({required this.items, required this.nextCursor});

  final List<Certificate> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
