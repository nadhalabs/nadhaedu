import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:learning_platform/core/connectivity/network_monitor.dart';
import 'package:learning_platform/features/downloads/data/download_file_manager.dart';
import 'package:learning_platform/features/downloads/domain/download_network_policy.dart';
import 'package:learning_platform/features/downloads/domain/download_repository.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:path/path.dart' as p;

final class DownloadManager {
  DownloadManager({
    required DownloadRepository repository,
    required DownloadFileManager fileManager,
    required NetworkMonitor networkMonitor,
    Dio? dio,
    int maxConcurrentDownloads = 2,
  }) : _repository = repository,
       _fileManager = fileManager,
       _networkMonitor = networkMonitor,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 15),
             ),
           ),
       _maxConcurrent = maxConcurrentDownloads;

  final DownloadRepository _repository;
  final DownloadFileManager _fileManager;
  final NetworkMonitor _networkMonitor;
  final Dio _dio;
  final int _maxConcurrent;

  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _activeTaskIds = {};
  final List<String> _queuedTaskIds = [];
  final Set<String> _pausedTaskIds = {};
  final Set<String> _cancelledTaskIds = {};

  final StreamController<DownloadTask> _taskUpdateController =
      StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get taskUpdates => _taskUpdateController.stream;

  Future<void> recoverInterruptedDownloads(String learnerId) async {
    final tasks = await _repository.getAllTasks(learnerId);
    for (final task in tasks.where((task) => task.isActive)) {
      final recovered = task.copyWith(
        state: DownloadState.queued,
        clearFailure: true,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(recovered);
      if (!_queuedTaskIds.contains(recovered.id)) {
        _queuedTaskIds.add(recovered.id);
      }
      _broadcast(recovered);
    }
    await _processQueue(learnerId);
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      token.cancel('Download manager disposed.');
    }
    _cancelTokens.clear();
    _activeTaskIds.clear();
    _queuedTaskIds.clear();
    _pausedTaskIds.clear();
    _cancelledTaskIds.clear();
    unawaited(_taskUpdateController.close());
  }

  Future<DownloadTask> enqueueDownload({
    required String learnerId,
    required DownloadResourceType resourceType,
    required String resourceId,
    required String courseId,
    String? lessonId,
    required String title,
    required String courseTitle,
    DownloadQuality quality = DownloadQuality.standard,
  }) async {
    final existing = await _repository.getTaskByResourceId(
      learnerId,
      resourceId,
    );
    if (existing != null) {
      if (existing.isCompleted) {
        return existing;
      }
      if (existing.isActive) {
        return existing;
      }
      // If paused or failed, resume/retry
      if (existing.isPaused || existing.isFailed) {
        return resumeDownload(learnerId, existing.id);
      }
    }

    final taskId = 'dl_${learnerId}_${resourceId}_${quality.name}';
    _pausedTaskIds.remove(taskId);
    _cancelledTaskIds.remove(taskId);

    final now = DateTime.now().toUtc();
    final task = DownloadTask(
      id: taskId,
      learnerId: learnerId,
      resourceType: resourceType,
      resourceId: resourceId,
      courseId: courseId,
      lessonId: lessonId,
      title: title,
      courseTitle: courseTitle,
      remoteAssetId: '',
      state: DownloadState.queued,
      bytesDownloaded: 0,
      totalBytes: 0,
      createdAt: now,
      updatedAt: now,
      quality: quality,
    );

    await _repository.saveTask(task);
    _broadcast(task);

    _queuedTaskIds.add(task.id);
    unawaited(_processQueue(learnerId));

    return task;
  }

  Future<DownloadTask> resumeDownload(String learnerId, String taskId) async {
    _pausedTaskIds.remove(taskId);
    _cancelledTaskIds.remove(taskId);

    final task = await _repository.getTask(learnerId, taskId);
    if (task == null) throw StateError('Task $taskId not found.');
    if (task.isActive || task.isCompleted) return task;

    final updated = task.copyWith(
      state: DownloadState.queued,
      clearFailure: true,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repository.saveTask(updated);
    _broadcast(updated);

    if (!_queuedTaskIds.contains(taskId) && !_activeTaskIds.contains(taskId)) {
      _queuedTaskIds.add(taskId);
    }
    unawaited(_processQueue(learnerId));
    return updated;
  }

  Future<void> pauseDownload(String learnerId, String taskId) async {
    _cancelTokens[taskId]?.cancel('User paused download.');
    _cancelTokens.remove(taskId);
    _activeTaskIds.remove(taskId);
    _queuedTaskIds.remove(taskId);
    _pausedTaskIds.add(taskId);

    final task = await _repository.getTask(learnerId, taskId);
    if (task != null) {
      final updated = task.copyWith(
        state: DownloadState.paused,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(updated);
      _broadcast(updated);
    }
    unawaited(_processQueue(learnerId));
  }

  Future<void> cancelDownload(String learnerId, String taskId) async {
    _cancelTokens[taskId]?.cancel('User cancelled download.');
    _cancelTokens.remove(taskId);
    _activeTaskIds.remove(taskId);
    _queuedTaskIds.remove(taskId);
    _cancelledTaskIds.add(taskId);

    final task = await _repository.getTask(learnerId, taskId);
    if (task != null) {
      if (task.localRelativePath != null) {
        await _fileManager.deleteFile(task.localRelativePath!);
      }
      final updated = task.copyWith(
        state: DownloadState.cancelled,
        bytesDownloaded: 0,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(updated);
      _broadcast(updated);
    }
    unawaited(_processQueue(learnerId));
  }

  Future<void> retryDownload(String learnerId, String taskId) async {
    _pausedTaskIds.remove(taskId);
    _cancelledTaskIds.remove(taskId);

    final task = await _repository.getTask(learnerId, taskId);
    if (task == null) return;
    final updated = task.copyWith(
      state: DownloadState.queued,
      clearFailure: true,
      retryCount: task.retryCount + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    await _repository.saveTask(updated);
    _broadcast(updated);

    if (!_queuedTaskIds.contains(taskId) && !_activeTaskIds.contains(taskId)) {
      _queuedTaskIds.add(taskId);
    }
    unawaited(_processQueue(learnerId));
  }

  Future<void> deleteDownload(String learnerId, String taskId) async {
    _cancelTokens[taskId]?.cancel('Download deleted.');
    _cancelTokens.remove(taskId);
    _activeTaskIds.remove(taskId);
    _queuedTaskIds.remove(taskId);
    _pausedTaskIds.remove(taskId);
    _cancelledTaskIds.remove(taskId);
    await _repository.deleteTask(learnerId, taskId);
    unawaited(_processQueue(learnerId));
  }

  Future<void> _processQueue(String learnerId) async {
    while (_activeTaskIds.length < _maxConcurrent &&
        _queuedTaskIds.isNotEmpty) {
      final nextTaskId = _queuedTaskIds.removeAt(0);
      if (_pausedTaskIds.contains(nextTaskId) ||
          _cancelledTaskIds.contains(nextTaskId)) {
        continue;
      }
      _activeTaskIds.add(nextTaskId);
      unawaited(_executeDownload(learnerId, nextTaskId));
    }
  }

  Future<void> _executeDownload(String learnerId, String taskId) async {
    if (_pausedTaskIds.contains(taskId) || _cancelledTaskIds.contains(taskId)) {
      _activeTaskIds.remove(taskId);
      return;
    }

    final initialTask = await _repository.getTask(learnerId, taskId);
    if (initialTask == null ||
        initialTask.state == DownloadState.paused ||
        initialTask.state == DownloadState.cancelled ||
        _pausedTaskIds.contains(taskId) ||
        _cancelledTaskIds.contains(taskId)) {
      _activeTaskIds.remove(taskId);
      return;
    }

    var currentTask = initialTask;

    try {
      // 1. Check network connectivity & policy
      final network = await _networkMonitor.currentStatus();
      if (network == NetworkStatus.offline) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.networkUnavailable,
          message: 'No internet connection available.',
        );
      }
      final networkPolicy = await _repository.getNetworkPolicy();
      if (networkPolicy.preference == NetworkDownloadPreference.wifiOnly &&
          network != NetworkStatus.wifi) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.networkUnavailable,
          message: 'Download is waiting for a Wi-Fi connection.',
        );
      }

      if (_pausedTaskIds.contains(taskId) ||
          _cancelledTaskIds.contains(taskId)) {
        return;
      }

      // 2. Preparing state: Request backend authorization
      currentTask = currentTask.copyWith(
        state: DownloadState.preparing,
        updatedAt: DateTime.now().toUtc(),
      );
      if (_pausedTaskIds.contains(taskId) ||
          _cancelledTaskIds.contains(taskId)) {
        return;
      }
      await _repository.saveTask(currentTask);
      if (_pausedTaskIds.contains(taskId) ||
          _cancelledTaskIds.contains(taskId)) {
        return;
      }
      _broadcast(currentTask);

      final auth = await _repository.requestDownloadAuthorization(
        learnerId: learnerId,
        resourceType: currentTask.resourceType,
        resourceId: currentTask.resourceId,
        quality: currentTask.quality,
      );

      // Check if task was cancelled or paused while awaiting authorization
      if (!_activeTaskIds.contains(taskId)) {
        return;
      }

      // 3. Storage pre-check
      final availableSpace = await _fileManager.getAvailableDiskSpace();
      if (availableSpace < auth.sizeBytes + (50 * 1024 * 1024)) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.insufficientStorage,
          message: 'Insufficient device storage space for download.',
          retryable: false,
        );
      }

      // 4. File destination setup
      final fileExt = p.extension(Uri.parse(auth.downloadUrl).path).isNotEmpty
          ? p.extension(Uri.parse(auth.downloadUrl).path)
          : '.mp4';
      final relativePath = p.join(
        'courses',
        currentTask.courseId,
        '${currentTask.resourceId}_${currentTask.quality.name}$fileExt',
      );
      final absolutePath = await _fileManager.resolveAbsolutePath(relativePath);
      await _fileManager.ensureDirectoryExists(p.dirname(absolutePath));

      // 5. Check existing partial file for resumable byte-range download
      final file = File(absolutePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      var existingBytes = await file.exists() ? await file.length() : 0;
      if (existingBytes > auth.sizeBytes) {
        // Corrupt partial file larger than total
        await file.delete();
        existingBytes = 0;
      }

      currentTask = currentTask.copyWith(
        remoteAssetId: auth.remoteAssetId,
        state: DownloadState.downloading,
        bytesDownloaded: existingBytes,
        totalBytes: auth.sizeBytes,
        expiresAt: auth.expiresAt,
        entitlementExpiresAt: auth.entitlementExpiresAt,
        checksum: auth.checksumSha256,
        assetVersion: auth.assetVersion,
        localRelativePath: relativePath,
        protectionPolicy: auth.protectionPolicy,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(currentTask);
      _broadcast(currentTask);

      // 6. Perform streamed resumable download
      final cancelToken = CancelToken();
      _cancelTokens[taskId] = cancelToken;

      await _streamToFile(
        downloadUrl: auth.downloadUrl,
        file: file,
        existingBytes: existingBytes,
        totalBytes: auth.sizeBytes,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          final now = DateTime.now().toUtc();
          final updatedTask = currentTask.copyWith(
            bytesDownloaded: received,
            totalBytes: total > 0 ? total : auth.sizeBytes,
            updatedAt: now,
          );
          currentTask = updatedTask;
          _throttleBroadcast(updatedTask);
        },
      );

      // 7. Verify file integrity (Size & SHA-256)
      final downloadedSize = await file.length();
      if (downloadedSize != auth.sizeBytes && auth.sizeBytes > 0) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.integrityFailure,
          message: 'Downloaded file size does not match expected size.',
          retryable: true,
        );
      }

      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(auth.checksumSha256)) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.integrityFailure,
          message:
              'Download authorization did not include a valid SHA-256 checksum.',
          retryable: false,
        );
      }
      final calculatedSha = await _fileManager.computeSha256(relativePath);
      if (calculatedSha.toLowerCase() != auth.checksumSha256.toLowerCase()) {
        throw const DownloadFailure(
          reason: DownloadFailureReason.integrityFailure,
          message: 'Downloaded file checksum verification failed.',
          retryable: true,
        );
      }

      // 8. Download subtitles if present
      final downloadedSubtitles = <DownloadedSubtitle>[];
      for (final sub in auth.subtitles) {
        try {
          final subRelative = p.join(
            'courses',
            currentTask.courseId,
            'subtitles',
            '${sub.id}.vtt',
          );
          final subAbsolute = await _fileManager.resolveAbsolutePath(
            subRelative,
          );
          await _fileManager.ensureDirectoryExists(p.dirname(subAbsolute));
          final subResponse = await _dio.get<String>(
            sub.url,
            options: Options(responseType: ResponseType.plain),
          );
          await File(subAbsolute).writeAsString(subResponse.data ?? '');
          downloadedSubtitles.add(
            DownloadedSubtitle(
              id: sub.id,
              label: sub.label,
              languageCode: sub.languageCode,
              localRelativePath: subRelative,
              remoteUrl: sub.url,
            ),
          );
        } on Object catch (_) {
          // Non-fatal subtitle download failure
        }
      }

      // 9. Mark task completed
      final completedNow = DateTime.now().toUtc();
      currentTask = currentTask.copyWith(
        state: DownloadState.completed,
        bytesDownloaded: auth.sizeBytes,
        totalBytes: auth.sizeBytes,
        completedAt: completedNow,
        updatedAt: completedNow,
        subtitles: downloadedSubtitles,
        clearFailure: true,
      );
      await _repository.saveTask(currentTask);
      _broadcast(currentTask);
    } on DownloadFailure catch (f) {
      currentTask = currentTask.copyWith(
        state: DownloadState.failed,
        failure: f,
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(currentTask);
      _broadcast(currentTask);
    } on DioException catch (dioErr) {
      if (!_activeTaskIds.contains(taskId)) {
        return;
      }
      if (CancelToken.isCancel(dioErr)) {
        // Cancelled / paused - state already set
      } else {
        final reason =
            dioErr.type == DioExceptionType.connectionTimeout ||
                dioErr.type == DioExceptionType.connectionError
            ? DownloadFailureReason.networkUnavailable
            : dioErr.response?.statusCode == 401 ||
                  dioErr.response?.statusCode == 403
            ? DownloadFailureReason.authorizationExpired
            : DownloadFailureReason.serverFailure;

        currentTask = currentTask.copyWith(
          state: DownloadState.failed,
          failure: DownloadFailure(
            reason: reason,
            message:
                'The download stopped. Check your connection and try again.',
            statusCode: dioErr.response?.statusCode,
            retryable: reason.isRetryable,
          ),
          updatedAt: DateTime.now().toUtc(),
        );
        await _repository.saveTask(currentTask);
        _broadcast(currentTask);
      }
    } on Object {
      if (!_activeTaskIds.contains(taskId)) {
        return;
      }
      currentTask = currentTask.copyWith(
        state: DownloadState.failed,
        failure: DownloadFailure(
          reason: DownloadFailureReason.unknown,
          message: 'We couldn’t finish this download. Please try again.',
          retryable: true,
        ),
        updatedAt: DateTime.now().toUtc(),
      );
      await _repository.saveTask(currentTask);
      _broadcast(currentTask);
    } finally {
      _cancelTokens.remove(taskId);
      _activeTaskIds.remove(taskId);
      unawaited(_processQueue(learnerId));
    }
  }

  Future<void> _streamToFile({
    required String downloadUrl,
    required File file,
    required int existingBytes,
    required int totalBytes,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        downloadUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {if (existingBytes > 0) 'Range': 'bytes=$existingBytes-'},
        ),
      );

      final status = response.statusCode;
      var resumeOffset = existingBytes;
      if (existingBytes > 0) {
        if (status == HttpStatus.partialContent) {
          final contentRange = response.headers.value('content-range');
          if (contentRange == null ||
              !contentRange.startsWith('bytes $existingBytes-')) {
            throw const DownloadFailure(
              reason: DownloadFailureReason.integrityFailure,
              message:
                  'Server returned an invalid byte range for download resume.',
            );
          }
        } else if (status == HttpStatus.ok) {
          resumeOffset = 0;
        } else {
          throw DownloadFailure(
            reason: DownloadFailureReason.serverFailure,
            message: 'Server does not support safe download resume.',
            statusCode: status,
          );
        }
      } else if (status != HttpStatus.ok &&
          status != HttpStatus.partialContent) {
        throw DownloadFailure(
          reason: DownloadFailureReason.serverFailure,
          message: 'Unexpected download response status.',
          statusCode: status,
        );
      }

      sink = file.openWrite(
        mode: resumeOffset > 0 ? FileMode.append : FileMode.write,
      );

      final stream = response.data?.stream;
      if (stream == null) throw StateError('Empty download response stream.');

      var current = resumeOffset;
      await for (final chunk in stream) {
        if (cancelToken.isCancelled) break;
        sink.add(chunk);
        current += chunk.length;
        onProgress(current, totalBytes);
      }
      await sink.flush();
    } finally {
      await sink?.close();
    }
  }

  DateTime _lastBroadcast = DateTime.fromMillisecondsSinceEpoch(0);
  void _throttleBroadcast(DownloadTask task) {
    final now = DateTime.now();
    if (now.difference(_lastBroadcast) > const Duration(milliseconds: 300)) {
      _lastBroadcast = now;
      _broadcast(task);
    }
  }

  void _broadcast(DownloadTask task) {
    if (!_taskUpdateController.isClosed) {
      _taskUpdateController.add(task);
    }
  }
}
