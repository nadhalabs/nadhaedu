import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/operations/data/cms_operations_repository.dart';

final cmsOperationsRepositoryProvider = Provider<CmsOperationsRepository>(
  (ref) => CmsOperationsRepository(ref.watch(apiClientProvider)),
);

final cmsOperationsDataProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, path) async {
      return switch (await ref
          .watch(cmsOperationsRepositoryProvider)
          .get(path)) {
        Success(value: final value) => value,
        Failure(failure: final failure) => throw failure,
      };
    });

final class CmsOperationsRequest {
  const CmsOperationsRequest(this.path, [this.query = const {}]);

  final String path;
  final Map<String, Object?> query;

  @override
  bool operator ==(Object other) =>
      other is CmsOperationsRequest &&
      other.path == path &&
      _mapEquals(other.query, query);

  @override
  int get hashCode {
    final keys = query.keys.toList()..sort();
    return Object.hash(
      path,
      Object.hashAll(keys.map((key) => Object.hash(key, query[key]))),
    );
  }
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

final cmsOperationsQueryProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, CmsOperationsRequest>((ref, request) async {
      return switch (await ref
          .watch(cmsOperationsRepositoryProvider)
          .get(request.path, query: request.query)) {
        Success(value: final value) => value,
        Failure(failure: final failure) => throw failure,
      };
    });
