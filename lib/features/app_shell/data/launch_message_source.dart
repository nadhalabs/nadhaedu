import 'package:learning_platform/features/app_shell/domain/launch_message.dart';

abstract interface class LaunchMessageSource {
  LaunchMessage read();
}

final class LocalLaunchMessageSource implements LaunchMessageSource {
  const LocalLaunchMessageSource();

  @override
  LaunchMessage read() =>
      const LaunchMessage('Production foundation is ready.');
}
