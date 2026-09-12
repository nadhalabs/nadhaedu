import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/core/networking/api_client.dart';
import 'package:nadha_cms/features/cms/media/media_upload.dart';

class UploadApi implements ApiClient {
  final calls = <String>[];
  @override
  Future<Result<Map<String, Object?>>> post(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, Object?> headers = const {},
    bool authenticated = true,
  }) async {
    calls.add(path);
    return Success(
      path.endsWith('complete')
          ? {'assetId': 'stable-video', 'status': 'ready'}
          : {'uploadToken': 'upload-ticket'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('upload selection, progress, verification and ready asset', (
    tester,
  ) async {
    final api = UploadApi();
    final upload = Completer<void>();
    Map<String, Object?>? ready;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          directUploaderProvider.overrideWithValue((
            data,
            video,
            progress,
          ) async {
            expect(video, isTrue);
            progress(.5);
            await upload.future;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MediaUpload(
              lessonId: 'lesson',
              onReady: (data) => ready = data,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose video and upload'));
    await tester.pump();
    expect(find.text('Uploading'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .5,
    );
    expect(api.calls, ['/api/v1/admin/media/uploads']);
    upload.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(ready?['assetId'], 'stable-video');
    expect(api.calls.last, '/api/v1/admin/media/uploads/complete');
  });
  testWidgets(
    'failed cover upload can retry and never finalizes missing file',
    (tester) async {
      final api = UploadApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(api),
            directUploaderProvider.overrideWithValue((
              data,
              video,
              progress,
            ) async {
              expect(video, isFalse);
              throw StateError('Interrupted');
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaUpload(
                courseId: 'offering',
                onReady: (_) => fail('Unexpected asset'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Upload offering cover'));
      await tester.pumpAndSettle();
      expect(find.text('Retry upload'), findsOneWidget);
      expect(api.calls.length, 1);
    },
  );
  testWidgets('saved cover shows a thumbnail and falls back on image failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MediaUpload(
              courseId: 'offering',
              posterUrl: 'https://invalid.example/cover.jpg',
              onReady: (_) {},
            ),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://invalid.example/cover.jpg',
    );
    expect(image.errorBuilder, isNotNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
