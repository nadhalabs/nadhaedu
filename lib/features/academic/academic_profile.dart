import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/core/networking/api_client.dart';
import 'package:learning_platform/core/persistence/key_value_store.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';

final class AcademicOption {
  const AcademicOption(this.id, this.name);
  factory AcademicOption.fromJson(Map<String, Object?> value) =>
      AcademicOption(value['id']! as String, value['name']! as String);
  final String id;
  final String name;
}

final class AcademicProfile {
  const AcademicProfile({
    required this.curriculumId,
    required this.standardId,
    this.streamId,
    required this.version,
  });
  factory AcademicProfile.fromJson(Map<String, Object?> value) =>
      AcademicProfile(
        curriculumId: value['activeCurriculumId']! as String,
        standardId: value['activeStandardId']! as String,
        streamId: value['activeStreamId'] as String?,
        version: value['profileVersion']! as int,
      );
  final String curriculumId;
  final String standardId;
  final String? streamId;
  final int version;
  String get cacheKey => '$curriculumId|$standardId|$streamId|$version';
  Map<String, Object?> toJson() => {
    'activeCurriculumId': curriculumId,
    'activeStandardId': standardId,
    'activeStreamId': streamId,
    'profileVersion': version,
  };
}

class AcademicRepository {
  AcademicRepository(
    this.client,
    this.store,
    this.learnerId, {
    this.isDevelopment = false,
  });
  final ApiClient client;
  final KeyValueStore store;
  final String learnerId;
  final bool isDevelopment;
  String get _key => 'academic.profile.v1.$learnerId';

  Future<Map<String, Object?>> _get(String path) async =>
      switch (await client.get(path)) {
        Success(value: final value) => value,
        Failure(failure: final failure) => throw failure,
      };
  Future<List<AcademicOption>> options(String path) async {
    if (isDevelopment) return developmentAcademicOptions[path] ?? const [];
    final json = await _get('/api/v1/academic/$path');
    return (json['items']! as List)
        .map(
          (x) => AcademicOption.fromJson(Map<String, Object?>.from(x as Map)),
        )
        .toList();
  }

  Future<AcademicProfile?> load() async {
    if (isDevelopment) {
      final raw = await store.readString(_key);
      return raw == null
          ? null
          : AcademicProfile.fromJson(
              Map<String, Object?>.from(jsonDecode(raw) as Map),
            );
    }
    final json = await _get('/api/v1/academic-profile');
    return json['profile'] == null
        ? null
        : AcademicProfile.fromJson(
            Map<String, Object?>.from(json['profile']! as Map),
          );
  }

  Future<AcademicProfile> save(
    String curriculum,
    String standard,
    String? stream,
  ) async {
    if (isDevelopment) {
      final standards = await options('curricula/$curriculum/standards');
      final streams = await options('standards/$standard/streams');
      if (!standards.any((x) => x.id == standard) ||
          (streams.isNotEmpty && !streams.any((x) => x.id == stream)) ||
          (streams.isEmpty && stream != null)) {
        throw StateError('Select a valid academic profile.');
      }
      final old = await load();
      final changed =
          old?.curriculumId != curriculum ||
          old?.standardId != standard ||
          old?.streamId != stream;
      final value = AcademicProfile(
        curriculumId: curriculum,
        standardId: standard,
        streamId: stream,
        version: (old?.version ?? 0) + (changed ? 1 : 0),
      );
      await store.writeString(_key, jsonEncode(value.toJson()));
      return value;
    }
    final response = await client.put(
      '/api/v1/academic-profile',
      body: {
        'activeCurriculumId': curriculum,
        'activeStandardId': standard,
        'activeStreamId': stream,
      },
    );
    return switch (response) {
      Success(value: final value) => AcademicProfile.fromJson(
        Map<String, Object?>.from(value['profile']! as Map),
      ),
      Failure(failure: final failure) => throw failure,
    };
  }
}

// A small explicit fixture. Production selectors always read server records.
const developmentAcademicOptions = <String, List<AcademicOption>>{
  'curricula': [
    AcademicOption('fixture-cbse', 'CBSE'),
    AcademicOption('fixture-kerala', 'Kerala State'),
  ],
  'curricula/fixture-cbse/standards': [
    AcademicOption('fixture-10', 'Class 10'),
  ],
  'curricula/fixture-kerala/standards': [
    AcademicOption('fixture-11', 'Plus One'),
  ],
  'standards/fixture-11/streams': [
    AcademicOption('fixture-science', 'Science'),
  ],
};

final academicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(
    ref.watch(apiClientProvider),
    ref.watch(keyValueStoreProvider),
    ref.watch(authControllerProvider.select((x) => x.session?.identity.id)) ??
        'anonymous',
    isDevelopment:
        ref.watch(appConfigProvider).environment == AppEnvironment.development,
  ),
);
final academicProfileProvider =
    AsyncNotifierProvider<AcademicProfileController, AcademicProfile?>(
      AcademicProfileController.new,
    );

class AcademicProfileController extends AsyncNotifier<AcademicProfile?> {
  int _generation = 0;
  @override
  Future<AcademicProfile?> build() {
    _generation++;
    ref.onDispose(() => _generation++);
    return ref.watch(academicRepositoryProvider).load();
  }

  Future<void> save(String curriculum, String standard, String? stream) async {
    final generation = _generation;
    final saved = await ref
        .read(academicRepositoryProvider)
        .save(curriculum, standard, stream);
    if (generation != _generation) return;
    if (saved.version >= (state.valueOrNull?.version ?? 0)) {
      state = AsyncData(saved);
    }
  }
}

final academicOptionsProvider = FutureProvider.autoDispose
    .family<List<AcademicOption>, String>(
      (ref, path) => ref.watch(academicRepositoryProvider).options(path),
    );

// Includes unresolved/error state, so a failed profile load cannot reuse another catalog.
final academicContextKeyProvider = Provider<String>((ref) {
  final profile = ref.watch(academicProfileProvider);
  if (profile.isLoading) return 'loading';
  if (profile.hasError) return 'unavailable';
  return profile.valueOrNull?.cacheKey ?? 'unconfigured';
});
