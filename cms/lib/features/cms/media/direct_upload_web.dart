import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> uploadFile(
  Map<String, Object?> authorization,
  bool video,
  void Function(double) progress,
) async {
  final picker = web.HTMLInputElement()
    ..type = 'file'
    ..accept = video
        ? 'video/mp4,video/quicktime,video/webm'
        : 'image/jpeg,image/png,image/webp';
  final selected = Completer<web.File?>();
  picker.onchange = ((web.Event _) {
    if (!selected.isCompleted) selected.complete(picker.files?.item(0));
  }).toJS;
  picker.oncancel = ((web.Event _) {
    if (!selected.isCompleted) selected.complete(null);
  }).toJS;
  picker.click();
  final file = await selected.future;
  if (file == null) {
    throw StateError('Selection cancelled. Choose a file to retry.');
  }
  if (file.size <= 0 ||
      file.size > (video ? 2 * 1024 * 1024 * 1024 : 10 * 1024 * 1024)) {
    throw StateError(
      video ? 'Choose a video under 2 GB.' : 'Choose an image under 10 MB.',
    );
  }
  const chunkSize = 10 * 1024 * 1024;
  final uploadId = 'nadha-${DateTime.now().microsecondsSinceEpoch}';
  for (var start = 0; start < file.size; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, file.size);
    final form = web.FormData();
    (authorization['fields']! as Map).forEach(
      (key, value) => form.append('$key', '$value'.toJS),
    );
    form.append('file', file.slice(start, end), file.name);
    final xhr = web.XMLHttpRequest();
    final done = Completer<void>();
    xhr.open('POST', authorization['uploadUrl']! as String);
    xhr.timeout = 120000;
    if (video) {
      xhr.setRequestHeader('X-Unique-Upload-Id', uploadId);
      xhr.setRequestHeader(
        'Content-Range',
        'bytes $start-${end - 1}/${file.size}',
      );
    }
    xhr.upload.onprogress = ((web.ProgressEvent event) {
      progress(
        (start +
                (end - start) *
                    (event.lengthComputable ? event.loaded / event.total : 0)) /
            file.size,
      );
    }).toJS;
    xhr.onload = ((web.Event _) {
      if (xhr.status >= 200 && xhr.status < 300) {
        done.complete();
      } else {
        done.completeError(
          StateError('Upload failed (${xhr.status}). Retry with the file.'),
        );
      }
    }).toJS;
    void fail(web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          StateError('Upload interrupted. Retry with the file.'),
        );
      }
    }

    xhr.onerror = fail.toJS;
    xhr.ontimeout = fail.toJS;
    xhr.onabort = fail.toJS;
    xhr.send(form);
    await done.future;
    progress(end / file.size);
  }
}

void openPreview(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
