import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nadha_cms/bootstrap/cms_providers.dart';
import 'package:nadha_cms/core/errors/result.dart';
import 'package:nadha_cms/features/cms/media/direct_upload.dart';

typedef DirectUploader =
    Future<void> Function(Map<String, Object?>, bool, void Function(double));
final directUploaderProvider = Provider<DirectUploader>((ref) => uploadFile);

class MediaUpload extends ConsumerStatefulWidget {
  const MediaUpload({
    super.key,
    this.lessonId,
    this.courseId,
    this.replaceAssetId,
    this.posterUrl,
    required this.onReady,
    this.onBusy,
  });
  final String? lessonId, courseId, replaceAssetId, posterUrl;
  final void Function(Map<String, Object?>) onReady;
  final void Function(bool)? onBusy;
  @override
  ConsumerState<MediaUpload> createState() => _MediaUploadState();
}

class _MediaUploadState extends ConsumerState<MediaUpload> {
  String status = '';
  String? poster;
  bool busy = false;
  double? progress;
  String? pendingToken;
  Future<void> upload() async {
    setState(() {
      busy = true;
      status = 'Selecting';
      progress = null;
    });
    widget.onBusy?.call(true);
    try {
      final api = ref.read(apiClientProvider);
      if (pendingToken == null) {
        final auth = await api.post(
          '/api/v1/admin/media/uploads',
          body: {
            'lessonId': widget.lessonId,
            'courseId': widget.courseId,
            'replaceAssetId': widget.replaceAssetId,
          },
        );
        if (auth case Failure(failure: final error)) {
          throw StateError(error.message);
        }
        final data = (auth as Success<Map<String, Object?>>).value;
        await ref.read(directUploaderProvider)(data, widget.lessonId != null, (
          value,
        ) {
          if (mounted) {
            setState(() {
              status = 'Uploading';
              progress = value;
            });
          }
        });
        pendingToken = data['uploadToken']! as String;
      }
      if (mounted) {
        setState(() {
          status = 'Processing / verifying';
          progress = null;
        });
      }
      final result = await api.post(
        '/api/v1/admin/media/uploads/complete',
        body: {'uploadToken': pendingToken},
      );
      if (result case Failure(failure: final error)) {
        throw StateError(error.message);
      }
      final data = (result as Success<Map<String, Object?>>).value;
      if (!mounted) return;
      setState(() {
        status = 'Ready';
        poster = (data['posterUrl'] ?? data['coverReference']) as String?;
      });
      pendingToken = null;
      widget.onReady(data);
    } on Object catch (error) {
      if (mounted) setState(() => status = 'Failed: $error');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusy?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if ((poster ?? widget.posterUrl) != null)
        Image.network(
          (poster ?? widget.posterUrl)!,
          height: 150,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.image_not_supported_outlined),
        ),
      OutlinedButton.icon(
        onPressed: busy ? null : upload,
        icon: const Icon(Icons.upload),
        label: Text(
          status.startsWith('Failed')
              ? 'Retry upload'
              : widget.lessonId == null
              ? 'Upload offering cover'
              : widget.replaceAssetId == null
              ? 'Choose video and upload'
              : 'Replace video',
        ),
      ),
      if (busy) LinearProgressIndicator(value: progress),
      if (status.isNotEmpty) Text(status),
    ],
  );
}
