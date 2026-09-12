import 'package:learning_platform/features/downloads/domain/download_authorization.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/domain/storage_summary.dart';

abstract interface class DownloadRepository {
  Future<List<DownloadTask>> getAllTasks(String learnerId);
  Future<DownloadTask?> getTask(String learnerId, String taskId);
  Future<DownloadTask?> getTaskByResourceId(
    String learnerId,
    String resourceId,
  );
  Future<List<DownloadTask>> getTasksByCourseId(
    String learnerId,
    String courseId,
  );
  Future<void> saveTask(DownloadTask task);
  Future<void> deleteTask(String learnerId, String taskId);
  Future<void> deleteTasksForCourse(String learnerId, String courseId);
  Future<void> deleteAllTasks(String learnerId);
  Future<DownloadAuthorization> requestDownloadAuthorization({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    DownloadQuality quality = DownloadQuality.standard,
  });
  Future<List<DownloadRevalidationResult>> revalidateDownloads({
    required String learnerId,
    required List<String> resourceIds,
  });
  Future<StorageSummary> getStorageSummary(String learnerId);
  Future<DownloadNetworkPolicy> getNetworkPolicy();
  Future<void> setNetworkPolicy(DownloadNetworkPolicy policy);
}
