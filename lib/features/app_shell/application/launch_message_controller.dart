import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_platform/features/app_shell/data/launch_message_source.dart';
import 'package:learning_platform/features/app_shell/domain/launch_message.dart';

final launchMessageSourceProvider = Provider<LaunchMessageSource>(
  (ref) => const LocalLaunchMessageSource(),
);
final launchMessageProvider = Provider<LaunchMessage>(
  (ref) => ref.watch(launchMessageSourceProvider).read(),
);
