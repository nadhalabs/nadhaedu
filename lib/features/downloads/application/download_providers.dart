import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/config/app_environment.dart';
import 'package:learning_platform/features/authentication/application/auth_providers.dart';
import 'package:learning_platform/features/downloads/application/download_controller.dart';
import 'package:learning_platform/features/downloads/application/download_manager.dart';
import 'package:learning_platform/features/downloads/data/download_data_source.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/data/download_repository_impl.dart';
import 'package:learning_platform/features/downloads/data/download_task_store.dart';
import 'package:learning_platform/features/downloads/data/foundation_download_data_source.dart';
import 'package:learning_platform/features/downloads/data/remote_download_data_source.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_repository.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/domain/storage_summary.dart';

final currentLearnerIdProvider = Provider<String>((ref) {
  final learnerId = ref.watch(authControllerProvider).session?.identity.id;
  if (learnerId == null || learnerId.isEmpty) {
    throw StateError('An authenticated learner is required for downloads.');
  }
  return learnerId;
});

final downloadDataSourceProvider = Provider<DownloadDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  return switch (config.environment) {
    AppEnvironment.development => const FoundationDownloadDataSource(),
    AppEnvironment.staging || AppEnvironment.production =>
      RemoteDownloadDataSource(ref.watch(apiClientProvider)),
  };
});

final downloadTaskStoreProvider = Provider<DownloadTaskStore>((ref) {
  return DownloadTaskStore(ref.watch(keyValueStoreProvider));
});

final downloadFileManagerProvider = Provider<DownloadFileManager>((ref) {
  return PlatformDownloadFileManager();
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepositoryImpl(
    remote: ref.watch(downloadDataSourceProvider),
    taskStore: ref.watch(downloadTaskStoreProvider),
    fileManager: ref.watch(downloadFileManagerProvider),
    preferencesStore: ref.watch(keyValueStoreProvider),
  );
});

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    repository: ref.watch(downloadRepositoryProvider),
    fileManager: ref.watch(downloadFileManagerProvider),
    networkMonitor: ref.watch(networkMonitorProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, AsyncValue<List<DownloadTask>>>((
      ref,
    ) {
      final learnerId = ref.watch(currentLearnerIdProvider);
      return DownloadController(
        repository: ref.watch(downloadRepositoryProvider),
        downloadManager: ref.watch(downloadManagerProvider),
        learnerId: learnerId,
      );
    });

final downloadTaskForResourceProvider = Provider.family<DownloadTask?, String>((
  ref,
  resourceId,
) {
  final state = ref.watch(downloadControllerProvider);
  return state.valueOrNull
      ?.where((t) => t.resourceId == resourceId)
      .firstOrNull;
});

final courseDownloadsProvider = Provider.family<List<DownloadTask>, String>((
  ref,
  courseId,
) {
  final state = ref.watch(downloadControllerProvider);
  return state.valueOrNull
          ?.where((t) => t.courseId == courseId)
          .toList(growable: false) ??
      const [];
});

final storageSummaryProvider = FutureProvider<StorageSummary>((ref) async {
  final learnerId = ref.watch(currentLearnerIdProvider);
  ref.watch(downloadControllerProvider); // reload when downloads change
  return ref.watch(downloadRepositoryProvider).getStorageSummary(learnerId);
});

final downloadNetworkPolicyProvider = FutureProvider<DownloadNetworkPolicy>((
  ref,
) async {
  return ref.watch(downloadRepositoryProvider).getNetworkPolicy();
});
