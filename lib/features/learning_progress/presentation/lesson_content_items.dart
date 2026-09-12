import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_platform/bootstrap/providers.dart';
import 'package:learning_platform/core/errors/result.dart';
import 'package:learning_platform/features/assessments/presentation/assessment_screen.dart';
import 'package:learning_platform/features/content_catalog/domain/course.dart';
import 'package:learning_platform/features/content_protection/domain/content_protection_policy.dart';
import 'package:learning_platform/features/content_protection/presentation/widgets/protected_content_gate.dart';
import 'package:learning_platform/features/downloads/domain/download_task.dart';
import 'package:learning_platform/features/downloads/presentation/widgets/download_action_button.dart';
import 'package:learning_platform/features/learning_progress/application/learning_controller.dart';
import 'package:learning_platform/features/learning_progress/presentation/video_lesson_player.dart';

final lessonContentBodyProvider = FutureProvider.autoDispose
    .family<String, String>((ref, id) async {
      return switch (await ref
          .watch(apiClientProvider)
          .get('/api/v1/lesson-content/$id')) {
        Success(value: final data) => data['body'] as String? ?? '',
        Failure(failure: final e) => throw e,
      };
    });

class LessonContentItems extends ConsumerWidget {
  const LessonContentItems({
    required this.lesson,
    required this.courseId,
    required this.courseTitle,
    required this.controller,
    required this.policy,
    required this.initialPosition,
    super.key,
  });
  final Lesson lesson;
  final String courseId;
  final String courseTitle;
  final LearningController controller;
  final ContentProtectionPolicy policy;
  final Duration initialPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lesson.contentItems.isEmpty) {
      return const Text(
        'No published content is currently available for this lesson.',
      );
    }
    final firstVideo = lesson.contentItems
        .where((i) => i.type == 'video')
        .firstOrNull
        ?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in lesson.contentItems) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              item.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (item.type == 'video' && item.referenceId != null)
            VideoLessonPlayer(
              key: ValueKey(item.id),
              assetId: item.referenceId!,
              policy: policy,
              initialPosition: item.id == firstVideo
                  ? initialPosition
                  : Duration.zero,
              onProgress: (position, duration) async {
                if (item.id == firstVideo) {
                  await controller.recordPosition(
                    position,
                    duration,
                    lessonId: lesson.id,
                  );
                }
              },
              onFlush: controller.refreshAuthoritativeProgress,
            ),
          if (item.type == 'note')
            ProtectedContentGate(
              policy: policy,
              child: item.body != null
                  ? Text(item.body!)
                  : ref
                        .watch(lessonContentBodyProvider(item.id))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => TextButton(
                            onPressed: () => ref.invalidate(
                              lessonContentBodyProvider(item.id),
                            ),
                            child: const Text('Unable to load note. Retry'),
                          ),
                          data: Text.new,
                        ),
            ),
          if (item.type == 'quiz' && item.assessmentId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Open quiz'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AssessmentScreen(
                      assessmentId: item.assessmentId!,
                      onPassed: () =>
                          unawaited(controller.refreshAuthoritativeProgress()),
                    ),
                  ),
                );
                await controller.refreshAuthoritativeProgress();
              },
            ),
          if (item.type == 'resource' && item.referenceId != null)
            DownloadActionButton(
              resourceType: DownloadResourceType.resource,
              resourceId: item.referenceId!,
              courseId: courseId,
              lessonId: lesson.id,
              title: item.title,
              courseTitle: courseTitle,
            ),
        ],
      ],
    );
  }
}
